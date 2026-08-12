// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title BasisPoints
/// Conversions between basis points and absolute amounts.
///
/// Every function here is pure. The library holds no storage, makes no
/// external calls, and moves no value.
library BasisPoints {
    /// @notice applyBps over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function applyBps(uint256 amount, uint256 bps) internal pure returns (uint256) {
        return (amount * bps) / 10_000;
    }

    /// @notice removeBps over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function removeBps(uint256 amount, uint256 bps) internal pure returns (uint256) {
        return amount - ((amount * bps) / 10_000);
    }

    /// @notice toBps over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function toBps(uint256 part, uint256 whole) internal pure returns (uint256) {
        return whole == 0 ? 0 : (part * 10_000) / whole;
    }

}
