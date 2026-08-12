// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "../interfaces/IERC20.sol";
import {IRewardDistributor} from "../interfaces/IRewardDistributor.sol";
import {SafeTransferLib} from "../libraries/SafeTransferLib.sol";
import {FixedPointMath} from "../libraries/FixedPointMath.sol";
import {Ownable2Step} from "../auth/Ownable2Step.sol";
import {FeeController} from "./FeeController.sol";
import {WithdrawalQueue} from "./WithdrawalQueue.sol";

/// @title StakingVault
/// @notice Single-asset staking vault issuing non-transferable shares.
/// @dev Exits are two-phase: {requestWithdrawal} burns shares and books the
///      asset amount into the queue, {completeWithdrawal} pays out once the
///      cooldown has elapsed.
///
///      Total assets are tracked in storage rather than read from the token
///      balance, so an unsolicited transfer into this contract cannot move the
///      share price.
///
///      Invariants:
///        - totalSupply == 0  <=>  totalAssets == 0.
///        - Shares are non-transferable; balanceOf only changes on deposit and
///          on withdrawal request.
///        - The reward distributor is checkpointed for an account before that
///          account's share balance changes.
contract StakingVault is Ownable2Step {
    using SafeTransferLib for IERC20;
    using FixedPointMath for uint256;

    /// @notice The staked asset.
    IERC20 public immutable asset;

    /// @notice Fee policy for exits.
    FeeController public immutable feeController;

    /// @notice Exit bookkeeping.
    WithdrawalQueue public immutable withdrawalQueue;

    /// @notice Reward accounting. Set once, after deployment.
    IRewardDistributor public rewardDistributor;

    /// @notice Account permitted to pause deposits alongside the owner.
    address public guardian;

    /// @notice When true, new deposits and yield accrual are rejected.
    bool public paused;

    /// @notice Total shares outstanding.
    uint256 public totalSupply;

    /// @notice Shares held per account. Non-transferable.
    mapping(address => uint256) public balanceOf;

    /// @notice Assets under management, tracked in storage.
    uint256 public totalAssets;

    uint256 private _entered;

    error Reentrancy();
    error Paused();
    error NotGuardian();
    error ZeroAmount();
    error ZeroShares();
    error DistributorAlreadySet();
    error InsufficientShares(uint256 held, uint256 requested);

    event Deposited(address indexed account, uint256 assets, uint256 shares);
    event WithdrawalRequested(address indexed account, uint256 indexed id, uint256 shares, uint256 assets);
    event WithdrawalCompleted(address indexed account, uint256 indexed id, uint256 assets, uint256 fee);
    event YieldAccrued(uint256 assets);
    event PausedSet(bool paused);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event RewardDistributorSet(address indexed distributor);

    modifier nonReentrant() {
        if (_entered == 1) revert Reentrancy();
        _entered = 1;
        _;
        _entered = 0;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(
        IERC20 asset_,
        address initialOwner,
        address initialGuardian,
        FeeController feeController_,
        uint64 cooldown_
    ) Ownable2Step(initialOwner) {
        require(address(asset_) != address(0), "ASSET_ZERO");
        require(address(feeController_) != address(0), "FEES_ZERO");
        asset = asset_;
        feeController = feeController_;
        guardian = initialGuardian;
        withdrawalQueue = new WithdrawalQueue(address(this), cooldown_);
    }

    // ---------------------------------------------------------------- views

    /// @notice Shares that `assets` would mint at the current exchange rate.
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0) return assets;
        return assets.mulDiv(supply, totalAssets);
    }

    /// @notice Assets that `shares` are currently worth.
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0) return shares;
        return shares.mulDiv(totalAssets, supply);
    }

    // ------------------------------------------------------------ user flow

    /// @notice Stake `assets` and receive shares.
    /// @dev Rounds shares down, which favours the vault over the depositor.
    function deposit(uint256 assets) external nonReentrant whenNotPaused returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();

        _checkpoint(msg.sender);

        shares = convertToShares(assets);
        if (shares == 0) revert ZeroShares();

        totalAssets += assets;
        totalSupply += shares;
        balanceOf[msg.sender] += shares;

        asset.safeTransferFrom(msg.sender, address(this), assets);

        emit Deposited(msg.sender, assets, shares);
    }

    /// @notice Burn `shares` and open a cooldown before the assets can be taken.
    /// @dev Deliberately callable while paused so a pause cannot trap funds.
    function requestWithdrawal(uint256 shares) external nonReentrant returns (uint256 id) {
        if (shares == 0) revert ZeroAmount();

        uint256 held = balanceOf[msg.sender];
        if (held < shares) revert InsufficientShares(held, shares);

        _checkpoint(msg.sender);

        uint256 assets = convertToAssets(shares);

        balanceOf[msg.sender] = held - shares;
        totalSupply -= shares;
        totalAssets -= assets;

        id = withdrawalQueue.enqueue(msg.sender, assets);

        emit WithdrawalRequested(msg.sender, id, shares, assets);
    }

    /// @notice Collect a matured withdrawal request, net of the exit fee.
    function completeWithdrawal(uint256 id) external nonReentrant returns (uint256 paid) {
        uint256 assets = withdrawalQueue.settle(id, msg.sender);

        uint256 fee = assets.mulDiv(feeController.withdrawalFeeBps(), feeController.BPS_DENOMINATOR());
        paid = assets - fee;

        if (fee != 0) {
            asset.safeTransfer(feeController.feeRecipient(), fee);
        }
        asset.safeTransfer(msg.sender, paid);

        emit WithdrawalCompleted(msg.sender, id, paid, fee);
    }

    // ----------------------------------------------------------- privileged

    /// @notice Push external yield into the vault, raising the share price.
    function accrueYield(uint256 assets) external onlyOwner nonReentrant whenNotPaused {
        if (assets == 0) revert ZeroAmount();
        require(totalSupply != 0, "NO_SUPPLY");

        totalAssets += assets;
        asset.safeTransferFrom(msg.sender, address(this), assets);

        emit YieldAccrued(assets);
    }

    /// @notice Wire up reward accounting. Callable once.
    function setRewardDistributor(IRewardDistributor distributor) external onlyOwner {
        if (address(rewardDistributor) != address(0)) revert DistributorAlreadySet();
        require(address(distributor) != address(0), "DISTRIBUTOR_ZERO");
        rewardDistributor = distributor;
        emit RewardDistributorSet(address(distributor));
    }

    function setGuardian(address newGuardian) external onlyOwner {
        emit GuardianUpdated(guardian, newGuardian);
        guardian = newGuardian;
    }

    /// @notice Halt deposits. Withdrawals are unaffected.
    function pause() external {
        if (msg.sender != owner && msg.sender != guardian) revert NotGuardian();
        paused = true;
        emit PausedSet(true);
    }

    /// @notice Resume deposits.
    function unpause() external onlyOwner {
        paused = false;
        emit PausedSet(false);
    }

    // ------------------------------------------------------------- internal

    /// @dev Settle reward accounting for `account` at its pre-change balance.
    function _checkpoint(address account) private {
        IRewardDistributor distributor = rewardDistributor;
        if (address(distributor) != address(0)) {
            distributor.checkpoint(account);
        }
    }
}
