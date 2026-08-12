// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ISupplyCap
/// Reports a ceiling on total deposits and the headroom beneath it.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface ISupplyCap {
    /// @notice cap as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function cap() external view returns (uint256);

    /// @notice remaining as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function remaining() external view returns (uint256);

}
