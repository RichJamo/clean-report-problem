// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IAccessRegistry
/// An external registry answering role membership questions.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface IAccessRegistry {
    /// @notice hasRole as defined by the integration target.
    /// @param role As specified by the counterparty contract.
    /// @param account As specified by the counterparty contract.
    /// @return The value reported by the counterparty contract.
    function hasRole(bytes32 role, address account) external view returns (bool);

    /// @notice roleAdmin as defined by the integration target.
    /// @param role As specified by the counterparty contract.
    /// @return The value reported by the counterparty contract.
    function roleAdmin(bytes32 role) external view returns (bytes32);

}
