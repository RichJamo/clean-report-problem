// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IERC20
/// @notice Minimal ERC-20 surface used by the vault and the reward distributor.
interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
