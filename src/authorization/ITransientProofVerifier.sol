// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ITransientProofVerifier
/// @notice Canonical interface for modules that can validate
///         execution-context proofs consumed by AkmenaPolicyBoundary.
interface ITransientProofVerifier {
    function verifyTransientProof(
        uint256 proofId,
        address operator,
        uint256 amount
    ) external view returns (bool);
}
