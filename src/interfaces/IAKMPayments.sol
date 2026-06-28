// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IAKMPayments
/// @notice ERC1363 payment extension interface for AKM.
interface IAKMPayments {
    function transferAndCall(address to, uint256 value) external returns (bool);

    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    function approveAndCall(address spender, uint256 value) external returns (bool);

    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}
