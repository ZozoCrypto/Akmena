// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Spender hook for ERC-1363 approveAndCall
interface IERC1363Spender {
    function onApprovalReceived(address owner, uint256 value, bytes calldata data) external returns (bytes4);
}