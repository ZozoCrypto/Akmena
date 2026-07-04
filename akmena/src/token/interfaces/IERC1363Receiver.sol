// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Receiver hook for ERC-1363 transferAndCall / transferFromAndCall
interface IERC1363Receiver {
    function onTransferReceived(address operator, address from, uint256 value, bytes calldata data) external returns (bytes4);
}