// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IYieldSource
/// An external position from which yield can be realised.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface IYieldSource {
    /// @notice pendingYield as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function pendingYield() external view returns (uint256);

    /// @notice harvest as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function harvest() external returns (uint256);

    /// @notice underlying as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function underlying() external view returns (address);

}
