// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title SafeCast
/// Narrowing conversions that revert rather than truncate.
///
/// Every function here is pure. The library holds no storage, makes no
/// external calls, and moves no value.
library SafeCast {
    /// @notice toUint64 over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "CAST_64");
        return uint64(value);
    }

    /// @notice toUint128 over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "CAST_128");
        return uint128(value);
    }

    /// @notice toUint96 over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "CAST_96");
        return uint96(value);
    }

}
