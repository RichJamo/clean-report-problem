// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IPriceFeed
/// A push oracle reporting a signed price at a fixed precision.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface IPriceFeed {
    /// @notice latestAnswer as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function latestAnswer() external view returns (int256);

    /// @notice decimals as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function decimals() external view returns (uint8);

    /// @notice latestTimestamp as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function latestTimestamp() external view returns (uint256);

}
