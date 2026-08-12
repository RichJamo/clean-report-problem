// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IEmergencyModule
/// Reports a system-wide halt condition and when it began.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface IEmergencyModule {
    /// @notice halted as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function halted() external view returns (bool);

    /// @notice haltedSince as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function haltedSince() external view returns (uint64);

    /// @notice reason as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function reason() external view returns (bytes32);

}
