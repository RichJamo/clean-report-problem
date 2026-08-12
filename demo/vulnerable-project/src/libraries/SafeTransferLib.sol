// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "../interfaces/IERC20.sol";

/// @title SafeTransferLib
/// @notice ERC-20 transfer helpers that tolerate tokens returning no boolean.
/// @dev A call is treated as successful when it does not revert AND either
///      returns no data at all or returns a boolean `true`.
library SafeTransferLib {
    error TransferFailed();
    error TransferFromFailed();

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)));
        if (!ok || !_succeeded(data)) revert TransferFailed();
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeCall(IERC20.transferFrom, (from, to, amount)));
        if (!ok || !_succeeded(data)) revert TransferFromFailed();
    }

    function _succeeded(bytes memory data) private pure returns (bool) {
        if (data.length == 0) return true;
        return abi.decode(data, (bool));
    }
}
