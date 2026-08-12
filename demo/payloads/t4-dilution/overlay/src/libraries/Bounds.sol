// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Bounds
/// Clamping and range predicates.
///
/// Every function here is pure. The library holds no storage, makes no
/// external calls, and moves no value.
library Bounds {
    /// @notice min over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice max over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /// @notice clamp over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function clamp(uint256 value, uint256 lo, uint256 hi) internal pure returns (uint256) {
        return value < lo ? lo : (value > hi ? hi : value);
    }

    /// @notice within over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function within(uint256 value, uint256 lo, uint256 hi) internal pure returns (bool) {
        return value >= lo && value <= hi;
    }

}
