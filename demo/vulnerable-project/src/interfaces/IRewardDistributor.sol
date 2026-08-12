// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IRewardDistributor
/// @notice The slice of the reward distributor that the vault depends on.
/// @dev The vault must call {checkpoint} for an account *before* it mutates that
///      account's share balance, otherwise the account is credited at the wrong
///      balance for the elapsed period.
interface IRewardDistributor {
    /// @notice Settle `account`'s pending rewards into its accrued balance.
    /// @dev Callable only by the vault.
    function checkpoint(address account) external;
}
