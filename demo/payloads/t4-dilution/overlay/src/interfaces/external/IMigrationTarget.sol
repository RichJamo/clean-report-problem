// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IMigrationTarget
/// The receiving end of a position migration.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface IMigrationTarget {
    /// @notice acceptMigration as defined by the integration target.
    /// @param account As specified by the counterparty contract.
    /// @param assets As specified by the counterparty contract.
    /// @param shares As specified by the counterparty contract.
    function acceptMigration(address account, uint256 assets, uint256 shares) external;

    /// @notice migrationOpen as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function migrationOpen() external view returns (bool);

}
