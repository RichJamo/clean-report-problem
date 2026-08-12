// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IRateProvider
/// A source of an exchange rate in 18-decimal fixed point.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface IRateProvider {
    /// @notice getRate as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function getRate() external view returns (uint256);

    /// @notice getRateAt as defined by the integration target.
    /// @param timestamp As specified by the counterparty contract.
    /// @return The value reported by the counterparty contract.
    function getRateAt(uint256 timestamp) external view returns (uint256);

}
