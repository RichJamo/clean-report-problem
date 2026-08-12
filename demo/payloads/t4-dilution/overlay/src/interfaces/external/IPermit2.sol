// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IPermit2
/// Signature-authorised transfer of an approved token.
///
/// Declared here so integration surfaces are pinned in one place rather than
/// being restated at each call site. This file contains declarations only and
/// no implementation.
interface IPermit2 {
    /// @notice permitTransferFrom as defined by the integration target.
    /// @param token As specified by the counterparty contract.
    /// @param from As specified by the counterparty contract.
    /// @param to As specified by the counterparty contract.
    /// @param amount As specified by the counterparty contract.
    /// @param deadline As specified by the counterparty contract.
    /// @param signature As specified by the counterparty contract.
    function permitTransferFrom(address token, address from, address to, uint256 amount, uint256 deadline, bytes calldata signature) external;

}
