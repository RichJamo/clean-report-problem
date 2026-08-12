// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IRouterAdapter
/// The surface a router integration exposes to this system. Declared here so
/// the shape is pinned in one place rather than being restated at each call
/// site. Declarations only; no implementation.
///
/// Adapters are queried, never trusted to hold accounting state. The figures
/// they report are treated as advisory and are reconciled against this
/// system's own records before being acted on.
interface IRouterAdapter {
    /// @notice The token this adapter operates on.
    /// @return The value reported by the router integration.
    function underlying() external view returns (address);

    /// @notice Assets currently held through this adapter.
    /// @return The value reported by the router integration.
    function totalManaged() external view returns (uint256);

    /// @notice Portion that could be realised immediately.
    /// @return The value reported by the router integration.
    function available() external view returns (uint256);

    /// @notice Timestamp of the most recent synchronisation.
    /// @return The value reported by the router integration.
    function lastSync() external view returns (uint64);

    /// @notice Whether the adapter is currently accepting flow.
    /// @return The value reported by the router integration.
    function isActive() external view returns (bool);

    /// @notice Amount that would result from moving the given amount.
    /// @param amount The amount to evaluate.
    /// @return The value reported by the router integration.
    function quote(uint256 amount) external returns (uint256);

    /// @notice Ceiling this adapter will accept.
    /// @return The value reported by the router integration.
    function capacity() external view returns (uint256);

    /// @notice Stable identifier for this adapter.
    /// @return The value reported by the router integration.
    function identifier() external view returns (bytes32);

}
