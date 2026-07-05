// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title AKMConstants
/// @author Akmena Protocol
/// @notice Global constants for the Akmena V1 Kernel.
library AKMConstants {
    // EIP-712 Domain Version
    string internal constant VERSION = "1";
    
    // Authorization Types (ERC-3009)
    bytes32 internal constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH = 
        keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)");

    // Capability Bits (for future CapabilityRegistry)
    uint256 internal constant CAP_PURCHASE = 1 << 0;
    uint256 internal constant CAP_TRANSFER = 1 << 1;
    uint256 internal constant CAP_DEPLOY   = 1 << 2;
}