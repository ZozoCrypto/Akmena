// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title LibTransientProof
/// @notice Domain-separated EIP-1153 transient proof receipts.
///
/// IMPORTANT:
/// - Escrow proofs and privacy proofs occupy different namespaces.
/// - A numeric identifier from one domain MUST NOT authenticate
///   an operation in another domain.
library LibTransientProof {
    bytes32 internal constant ESCROW_PROOF_NAMESPACE =
        keccak256("akmena.transient.proof.escrow");

    bytes32 internal constant PRIVACY_PROOF_NAMESPACE =
        keccak256("akmena.transient.proof.privacy");

    function _slot(
        bytes32 namespace,
        uint256 proofId,
        address subject,
        uint256 amount
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(namespace, proofId, subject, amount)
        );
    }

    /// @notice Write an escrow-domain transient proof.
    function setEscrowProof(
        uint256 escrowId,
        address buyer,
        uint256 amount
    ) internal {
        bytes32 slot = _slot(
            ESCROW_PROOF_NAMESPACE,
            escrowId,
            buyer,
            amount
        );

        assembly {
            tstore(slot, 1)
        }
    }

    /// @notice Verify an escrow-domain transient proof.
    function verifyEscrowProof(
        uint256 escrowId,
        address buyer,
        uint256 amount
    ) internal view returns (bool isValid) {
        bytes32 slot = _slot(
            ESCROW_PROOF_NAMESPACE,
            escrowId,
            buyer,
            amount
        );

        assembly {
            isValid := tload(slot)
        }
    }

    /// @notice Write a privacy-domain transient proof.
    function setPrivacyProof(
        uint256 nullifierHash,
        address recipient,
        uint256 amount
    ) internal {
        bytes32 slot = _slot(
            PRIVACY_PROOF_NAMESPACE,
            nullifierHash,
            recipient,
            amount
        );

        assembly {
            tstore(slot, 1)
        }
    }

    /// @notice Verify a privacy-domain transient proof.
    function verifyPrivacyProof(
        uint256 nullifierHash,
        address recipient,
        uint256 amount
    ) internal view returns (bool isValid) {
        bytes32 slot = _slot(
            PRIVACY_PROOF_NAMESPACE,
            nullifierHash,
            recipient,
            amount
        );

        assembly {
            isValid := tload(slot)
        }
    }
}
