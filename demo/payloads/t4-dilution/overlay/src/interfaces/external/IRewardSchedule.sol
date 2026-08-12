// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IRewardSchedule
/// Describes a reward rate over a bounded period.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface IRewardSchedule {
    /// @notice rateAt as defined by the integration target.
    /// @param timestamp As specified by the counterparty contract.
    /// @return The value reported by the counterparty contract.
    function rateAt(uint256 timestamp) external view returns (uint256);

    /// @notice periodStart as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function periodStart() external view returns (uint64);

    /// @notice periodEnd as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function periodEnd() external view returns (uint64);

}
