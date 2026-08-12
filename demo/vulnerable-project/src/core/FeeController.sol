// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "../auth/Ownable2Step.sol";

/// @title FeeController
/// @notice Holds the withdrawal fee parameters shared by the vault.
/// @dev Split out from the vault so fee policy can be reviewed and changed
///      without touching share accounting.
///
///      Invariants:
///        - withdrawalFeeBps <= MAX_FEE_BPS at all times.
///        - feeRecipient is never the zero address.
contract FeeController is Ownable2Step {
    /// @notice Basis-point denominator.
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Hard ceiling on the withdrawal fee: 5%.
    uint256 public constant MAX_FEE_BPS = 500;

    /// @notice Fee charged on the asset amount leaving the vault, in bps.
    uint256 public withdrawalFeeBps;

    /// @notice Destination for collected fees.
    address public feeRecipient;

    error FeeTooHigh(uint256 requested, uint256 maximum);
    error ZeroAddress();

    event WithdrawalFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    constructor(address initialOwner, address initialRecipient, uint256 initialFeeBps)
        Ownable2Step(initialOwner)
    {
        if (initialRecipient == address(0)) revert ZeroAddress();
        if (initialFeeBps > MAX_FEE_BPS) revert FeeTooHigh(initialFeeBps, MAX_FEE_BPS);
        feeRecipient = initialRecipient;
        withdrawalFeeBps = initialFeeBps;
    }

    /// @notice Update the withdrawal fee.
    /// @dev Reverts if `newFeeBps` exceeds {MAX_FEE_BPS}.
    function setWithdrawalFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh(newFeeBps, MAX_FEE_BPS);
        emit WithdrawalFeeUpdated(withdrawalFeeBps, newFeeBps);
        withdrawalFeeBps = newFeeBps;
    }

    /// @notice Update the fee destination.
    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }
}
