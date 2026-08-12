// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IFeeSplitter
/// Divides an incoming amount between a fixed set of recipients.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface IFeeSplitter {
    /// @notice split as defined by the integration target.
    /// @param amount As specified by the counterparty contract.
    function split(uint256 amount) external;

    /// @notice shareOf as defined by the integration target.
    /// @param account As specified by the counterparty contract.
    /// @return The value reported by the counterparty contract.
    function shareOf(address account) external view returns (uint256);

    /// @notice recipientCount as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function recipientCount() external view returns (uint256);

}
