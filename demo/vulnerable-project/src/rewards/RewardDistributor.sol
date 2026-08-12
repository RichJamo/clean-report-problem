// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "../interfaces/IERC20.sol";
import {IRewardDistributor} from "../interfaces/IRewardDistributor.sol";
import {SafeTransferLib} from "../libraries/SafeTransferLib.sol";
import {FixedPointMath} from "../libraries/FixedPointMath.sol";
import {Ownable2Step} from "../auth/Ownable2Step.sol";
import {StakingVault} from "../core/StakingVault.sol";

/// @title RewardDistributor
/// @notice Distributes a secondary reward token to vault stakers pro rata.
/// @dev Index-based accounting. `globalIndex` is the cumulative reward per share
///      in WAD. An account's entitlement since it was last seen is
///      `balance * (globalIndex - userIndex[account]) / WAD`. The vault calls
///      {checkpoint} before it mutates a balance, which folds that entitlement
///      into `accrued[account]` so the balance change cannot backdate rewards.
///
///      Rewards are pushed in by the owner via {notifyReward}; nothing streams,
///      so `globalIndex` only moves at notification time.
contract RewardDistributor is IRewardDistributor, Ownable2Step {
    using SafeTransferLib for IERC20;
    using FixedPointMath for uint256;

    /// @notice The token paid out to stakers.
    IERC20 public immutable rewardToken;

    /// @notice The vault whose share balances define each account's weight.
    StakingVault public immutable vault;

    /// @notice Cumulative reward per share, in WAD.
    uint256 public globalIndex;

    /// @notice Value of `globalIndex` when each account was last checkpointed.
    mapping(address => uint256) public userIndex;

    /// @notice Rewards settled for an account but not yet paid out.
    mapping(address => uint256) public accrued;

    /// @notice Total rewards notified over the life of the contract.
    uint256 public totalNotified;

    /// @notice Total rewards paid out over the life of the contract.
    uint256 public totalClaimed;

    uint256 private _entered;

    error Reentrancy();
    error NotVault();
    error ZeroAmount();
    error NoStakers();
    error NothingToClaim();

    event RewardNotified(uint256 amount, uint256 newGlobalIndex);
    event Checkpointed(address indexed account, uint256 accruedTotal);
    event Claimed(address indexed account, uint256 amount);

    modifier nonReentrant() {
        if (_entered == 1) revert Reentrancy();
        _entered = 1;
        _;
        _entered = 0;
    }

    modifier onlyVault() {
        if (msg.sender != address(vault)) revert NotVault();
        _;
    }

    constructor(IERC20 rewardToken_, StakingVault vault_, address initialOwner)
        Ownable2Step(initialOwner)
    {
        require(address(rewardToken_) != address(0), "REWARD_ZERO");
        require(address(vault_) != address(0), "VAULT_ZERO");
        rewardToken = rewardToken_;
        vault = vault_;
    }

    // ---------------------------------------------------------------- views

    /// @notice Rewards `account` could take right now.
    function claimable(address account) public view returns (uint256) {
        return accrued[account] + _pendingFor(account);
    }

    // ------------------------------------------------------------ accounting

    /// @notice Fold `account`'s elapsed entitlement into its accrued balance.
    /// @dev Called by the vault immediately before a share balance changes.
    function checkpoint(address account) external onlyVault {
        uint256 pending = _pendingFor(account);
        if (pending != 0) {
            accrued[account] += pending;
        }
        userIndex[account] = globalIndex;

        emit Checkpointed(account, accrued[account]);
    }

    /// @notice Fund the distributor and raise the reward index.
    /// @dev Requires a non-zero share supply, otherwise the rewards would have
    ///      no one to attribute to and would be stranded.
    function notifyReward(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();

        uint256 supply = vault.totalSupply();
        if (supply == 0) revert NoStakers();

        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        totalNotified += amount;
        globalIndex += amount.mulDiv(FixedPointMath.WAD, supply);

        emit RewardNotified(amount, globalIndex);
    }

    /// @notice Pay out the caller's rewards.
    /// @return amount The reward tokens transferred to the caller.
    function claim() external nonReentrant returns (uint256 amount) {
        amount = accrued[msg.sender] + _pendingFor(msg.sender);
        if (amount == 0) revert NothingToClaim();

        userIndex[msg.sender] = globalIndex;
        totalClaimed += amount;

        rewardToken.safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }

    // ------------------------------------------------------------- internal

    /// @dev Entitlement earned since `account` was last checkpointed.
    function _pendingFor(address account) private view returns (uint256) {
        uint256 delta = globalIndex - userIndex[account];
        if (delta == 0) return 0;
        return vault.balanceOf(account).mulDiv(delta, FixedPointMath.WAD);
    }
}
