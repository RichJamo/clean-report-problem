// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ITimelock
/// A delay enforced between proposing and executing a privileged action.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface ITimelock {
    /// @notice delay as defined by the integration target.
    /// @return The value reported by the counterparty contract.
    function delay() external view returns (uint256);

    /// @notice queuedAt as defined by the integration target.
    /// @param id As specified by the counterparty contract.
    /// @return The value reported by the counterparty contract.
    function queuedAt(bytes32 id) external view returns (uint256);

    /// @notice isReady as defined by the integration target.
    /// @param id As specified by the counterparty contract.
    /// @return The value reported by the counterparty contract.
    function isReady(bytes32 id) external view returns (bool);

}
