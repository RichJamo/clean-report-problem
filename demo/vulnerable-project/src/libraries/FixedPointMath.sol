// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title FixedPointMath
/// @notice Multiply-then-divide helpers with explicit rounding direction.
/// @dev Intermediate products are checked by the 0.8.x arithmetic rules, so an
///      overflow reverts rather than wrapping. Division by zero also reverts.
library FixedPointMath {
    /// @notice One unit in 18-decimal fixed point.
    uint256 internal constant WAD = 1e18;

    /// @notice Returns floor(x * y / d).
    /// @dev Precondition: d != 0. Postcondition: result <= x * y / d.
    function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y) / d;
    }

    /// @notice Returns ceil(x * y / d).
    /// @dev Precondition: d != 0. Postcondition: result >= x * y / d.
    function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        uint256 p = x * y;
        return p == 0 ? 0 : ((p - 1) / d) + 1;
    }
}
