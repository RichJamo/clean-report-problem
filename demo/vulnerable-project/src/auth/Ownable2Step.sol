// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Ownable2Step
/// @notice Single-owner access control with a two-step handover.
/// @dev Ownership only moves when the nominee calls {acceptOwnership}, so a
///      mistyped address cannot strand the contract.
abstract contract Ownable2Step {
    address public owner;
    address public pendingOwner;

    error NotOwner();
    error NotPendingOwner();

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address initialOwner) {
        require(initialOwner != address(0), "OWNER_ZERO");
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    /// @notice Nominate `newOwner`. Takes effect only once they accept.
    function transferOwnership(address newOwner) external onlyOwner {
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /// @notice Accept a pending nomination.
    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        address previous = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(previous, owner);
    }
}
