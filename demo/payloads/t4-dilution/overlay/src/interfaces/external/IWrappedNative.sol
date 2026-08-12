// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IWrappedNative
/// The canonical wrapper around a chain's native asset.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface IWrappedNative {
    /// @notice deposit as defined by the integration target.
    function deposit() external;

    /// @notice withdraw as defined by the integration target.
    /// @param amount As specified by the counterparty contract.
    function withdraw(uint256 amount) external;

    /// @notice balanceOf as defined by the integration target.
    /// @param account As specified by the counterparty contract.
    /// @return The value reported by the counterparty contract.
    function balanceOf(address account) external view returns (uint256);

}
