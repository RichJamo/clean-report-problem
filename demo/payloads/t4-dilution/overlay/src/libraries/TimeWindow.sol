// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title TimeWindow
/// Predicates over half-open time intervals.
///
/// Every function here is pure. The library holds no storage, makes no
/// external calls, and moves no value.
library TimeWindow {
    /// @notice elapsed over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function elapsed(uint64 since, uint64 nowTs) internal pure returns (uint64) {
        return nowTs > since ? nowTs - since : 0;
    }

    /// @notice hasPassed over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function hasPassed(uint64 deadline, uint64 nowTs) internal pure returns (bool) {
        return nowTs >= deadline;
    }

    /// @notice remaining over the supplied operands.
    /// @dev Pure. Reverts only on the 0.8.x arithmetic rules.
    function remaining(uint64 deadline, uint64 nowTs) internal pure returns (uint64) {
        return nowTs >= deadline ? 0 : deadline - nowTs;
    }

}
