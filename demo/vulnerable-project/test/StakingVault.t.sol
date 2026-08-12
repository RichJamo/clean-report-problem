// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "../src/interfaces/IERC20.sol";
import {StakingVault} from "../src/core/StakingVault.sol";
import {FeeController} from "../src/core/FeeController.sol";
import {WithdrawalQueue} from "../src/core/WithdrawalQueue.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {TestBase} from "./utils/TestBase.sol";

contract StakingVaultTest is TestBase {
    uint64 internal constant COOLDOWN = 3 days;
    uint256 internal constant FEE_BPS = 50; // 0.5%

    MockERC20 internal asset;
    FeeController internal fees;
    StakingVault internal vault;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal guardian = address(0x64A4D);
    address internal feeSink = address(0xFEE5);

    function setUp() public {
        vm.warp(1_700_000_000);

        asset = new MockERC20("Asset", "AST");
        fees = new FeeController(address(this), feeSink, FEE_BPS);
        vault = new StakingVault(IERC20(address(asset)), address(this), guardian, fees, COOLDOWN);

        asset.mint(alice, 1_000 ether);
        asset.mint(bob, 1_000 ether);
        asset.mint(address(this), 1_000 ether);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);
        asset.approve(address(vault), type(uint256).max);
    }

    function test_FirstDepositMintsSharesOneToOne() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(100 ether);

        assertEq(shares, 100 ether, "shares != assets on first deposit");
        assertEq(vault.balanceOf(alice), 100 ether, "alice share balance");
        assertEq(vault.totalAssets(), 100 ether, "totalAssets");
        assertEq(vault.totalSupply(), 100 ether, "totalSupply");
    }

    function test_DepositAfterYieldMintsFewerShares() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        // Share price doubles: 100 assets backed by 100 shares becomes 200/100.
        vault.accrueYield(100 ether);
        assertEq(vault.convertToAssets(100 ether), 200 ether, "share price did not move");

        vm.prank(bob);
        uint256 shares = vault.deposit(100 ether);

        assertEq(shares, 50 ether, "bob should mint at the raised price");
        assertEq(vault.totalAssets(), 300 ether, "totalAssets after bob");
    }

    function test_DonationDoesNotMoveSharePrice() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        // An unsolicited transfer is not accounting.
        vm.prank(bob);
        asset.transfer(address(vault), 500 ether);

        assertEq(vault.convertToAssets(100 ether), 100 ether, "donation moved the price");
    }

    function test_WithdrawalIsLockedUntilCooldownElapses() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        vm.prank(alice);
        uint256 id = vault.requestWithdrawal(100 ether);

        assertEq(vault.balanceOf(alice), 0, "shares should burn at request time");
        assertEq(vault.totalAssets(), 0, "assets should leave accounting at request time");

        vm.prank(alice);
        try vault.completeWithdrawal(id) {
            revert("completed before cooldown elapsed");
        } catch {}

        vm.warp(block.timestamp + COOLDOWN);

        vm.prank(alice);
        uint256 paid = vault.completeWithdrawal(id);
        assertTrue(paid != 0, "no payout after cooldown");
    }

    function test_CompleteWithdrawalPaysNetOfFee() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        uint256 id = vault.requestWithdrawal(100 ether);

        vm.warp(block.timestamp + COOLDOWN);

        uint256 before = asset.balanceOf(alice);
        vm.prank(alice);
        uint256 paid = vault.completeWithdrawal(id);

        uint256 expectedFee = (100 ether * FEE_BPS) / fees.BPS_DENOMINATOR();

        assertEq(paid, 100 ether - expectedFee, "payout not net of fee");
        assertEq(asset.balanceOf(alice) - before, paid, "alice balance delta");
        assertEq(asset.balanceOf(feeSink), expectedFee, "fee sink balance");
    }

    function test_RequestCannotBeSettledTwice() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        uint256 id = vault.requestWithdrawal(100 ether);

        vm.warp(block.timestamp + COOLDOWN);

        vm.prank(alice);
        vault.completeWithdrawal(id);

        vm.prank(alice);
        try vault.completeWithdrawal(id) {
            revert("settled the same request twice");
        } catch {}
    }

    function test_RequestCannotBeSettledByAnotherAccount() public {
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.prank(alice);
        uint256 id = vault.requestWithdrawal(100 ether);

        vm.warp(block.timestamp + COOLDOWN);

        vm.prank(bob);
        try vault.completeWithdrawal(id) {
            revert("bob settled alice's request");
        } catch {}
    }

    function test_PauseStopsDepositsButNotExits() public {
        vm.prank(alice);
        vault.deposit(100 ether);

        vm.prank(guardian);
        vault.pause();

        vm.prank(bob);
        try vault.deposit(1 ether) {
            revert("deposit succeeded while paused");
        } catch {}

        // Exits stay open by design: a pause must not trap staked funds.
        vm.prank(alice);
        uint256 id = vault.requestWithdrawal(100 ether);
        vm.warp(block.timestamp + COOLDOWN);
        vm.prank(alice);
        vault.completeWithdrawal(id);

        assertEq(vault.balanceOf(alice), 0, "alice could not exit while paused");
    }

    function test_FeeIsCapped() public {
        try fees.setWithdrawalFeeBps(fees.MAX_FEE_BPS() + 1) {
            revert("fee above the cap was accepted");
        } catch {}

        fees.setWithdrawalFeeBps(fees.MAX_FEE_BPS());
        assertEq(fees.withdrawalFeeBps(), fees.MAX_FEE_BPS(), "fee not updated to the cap");
    }

    function test_OnlyVaultCanEnqueue() public {
        WithdrawalQueue queue = vault.withdrawalQueue();
        try queue.enqueue(alice, 1 ether) {
            revert("non-vault caller enqueued");
        } catch {}
    }
}
