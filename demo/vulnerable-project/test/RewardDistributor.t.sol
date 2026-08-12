// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "../src/interfaces/IERC20.sol";
import {IRewardDistributor} from "../src/interfaces/IRewardDistributor.sol";
import {StakingVault} from "../src/core/StakingVault.sol";
import {FeeController} from "../src/core/FeeController.sol";
import {RewardDistributor} from "../src/rewards/RewardDistributor.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {TestBase} from "./utils/TestBase.sol";

contract RewardDistributorTest is TestBase {
    uint64 internal constant COOLDOWN = 3 days;

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
        vault = new StakingVault(IERC20(address(asset)), address(this), address(0), fees, COOLDOWN);
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

    function _stake(address who, uint256 amount) internal {
        vm.prank(who);
        vault.deposit(amount);
    }

    function test_NotifyRaisesTheGlobalIndex() public {
        _stake(alice, 100 ether);

        distributor.notifyReward(10 ether);

        assertEq(distributor.totalNotified(), 10 ether, "totalNotified");
        // 10 reward tokens over 100 shares is 0.1 per share.
        assertEq(distributor.globalIndex(), 0.1 ether, "globalIndex");
    }

    function test_NotifyRevertsWithNoStakers() public {
        try distributor.notifyReward(10 ether) {
            revert("notified with an empty vault");
        } catch {}
    }

    function test_RewardsSplitProRata() public {
        _stake(alice, 300 ether);
        _stake(bob, 100 ether);

        distributor.notifyReward(100 ether);

        assertEq(distributor.claimable(alice), 75 ether, "alice claimable");
        assertEq(distributor.claimable(bob), 25 ether, "bob claimable");
    }

    function test_ClaimTransfersTheRewardToken() public {
        _stake(alice, 300 ether);
        _stake(bob, 100 ether);

        distributor.notifyReward(100 ether);

        vm.prank(alice);
        uint256 amount = distributor.claim();

        assertEq(amount, 75 ether, "claim return value");
        assertEq(reward.balanceOf(alice), 75 ether, "alice reward balance");
        assertEq(distributor.totalClaimed(), 75 ether, "totalClaimed");
    }

    function test_StakingAfterANotificationEarnsNothingRetroactively() public {
        _stake(alice, 100 ether);

        distributor.notifyReward(50 ether);

        // Bob arrives after the reward was notified.
        _stake(bob, 100 ether);

        assertEq(distributor.claimable(bob), 0, "late staker earned retroactively");
        assertEq(distributor.claimable(alice), 50 ether, "early staker shortchanged");
    }

    function test_DepositCheckpointsEarlierEntitlement() public {
        _stake(alice, 100 ether);

        distributor.notifyReward(40 ether);

        // The second deposit checkpoints alice at her pre-change balance, so the
        // 40 already earned is banked rather than recomputed at the new balance.
        _stake(alice, 100 ether);

        assertEq(distributor.accrued(alice), 40 ether, "accrued after checkpoint");
        assertEq(distributor.claimable(alice), 40 ether, "claimable after checkpoint");

        vm.prank(alice);
        uint256 amount = distributor.claim();
        assertEq(amount, 40 ether, "claim after checkpoint");
    }

    function test_WithdrawalCheckpointsBeforeBalanceChange() public {
        _stake(alice, 100 ether);

        distributor.notifyReward(40 ether);

        vm.prank(alice);
        vault.requestWithdrawal(100 ether);

        // Exiting does not forfeit rewards already earned.
        assertEq(distributor.claimable(alice), 40 ether, "exit forfeited rewards");
    }

    function test_CheckpointIsVaultOnly() public {
        try distributor.checkpoint(alice) {
            revert("non-vault caller checkpointed");
        } catch {}
    }

    function test_NotifyIsOwnerOnly() public {
        _stake(alice, 100 ether);
        vm.prank(bob);
        try distributor.notifyReward(1 ether) {
            revert("non-owner notified");
        } catch {}
    }
}
