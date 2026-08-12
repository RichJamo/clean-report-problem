// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice The subset of the Foundry cheatcode interface this suite needs.
interface Vm {
    function warp(uint256 timestamp) external;
    function prank(address sender) external;
}

/// @notice Assertion helpers. A failing assertion reverts, which fails the test.
abstract contract TestBase {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function assertEq(uint256 actual, uint256 expected, string memory what) internal pure {
        require(actual == expected, what);
    }

    function assertTrue(bool condition, string memory what) internal pure {
        require(condition, what);
    }
}
