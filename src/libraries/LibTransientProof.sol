// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibTransientProof {
    // EIP-1153 Transient storage slots
    // Slot layout for transient escrow receipts
    bytes32 constant ESCROW_PROOF_NAMESPACE = keccak256("akmena.transient.escrow.proof");

    function setEscrowProof(uint256 escrowId, address buyer, uint256 amount) internal {
        bytes32 slot = keccak256(abi.encodePacked(ESCROW_PROOF_NAMESPACE, escrowId, buyer, amount));
        assembly {
            tstore(slot, 1)
        }
    }

    function verifyEscrowProof(uint256 escrowId, address buyer, uint256 amount) internal view returns (bool isValid) {
        bytes32 slot = keccak256(abi.encodePacked(ESCROW_PROOF_NAMESPACE, escrowId, buyer, amount));
        assembly {
            isValid := tload(slot)
        }
    }
}
