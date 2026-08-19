// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAttestationEngine} from "./IAttestationEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract AttestationEngine is IAttestationEngine, EIP712 {
    using ECDSA for bytes32;

    bytes32 private constant RECORD_ATTESTATION_TYPEHASH = keccak256("RecordAttestation(address subject,bytes32 attestationHash,uint256 nonce,uint256 deadline)");
    mapping(address => uint256) public nonces;

    constructor() EIP712("AkmenaAttestationEngine", "1") {}

    function recordAttestation(address subject, bytes32 attestationHash) external override {
        if (subject == address(0)) revert InvalidAddress();
        if (attestationHash == bytes32(0)) revert EmptyAttestation();

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        ds.attestations[subject][msg.sender][attestationHash] = true;

        emit AttestationRecorded(subject, msg.sender, attestationHash);
    }

    /// @notice FORTIFIED: Cryptographically verified attestation via EIP-712 signature
    function recordAttestationTyped(
        address attester,
        address subject,
        bytes32 attestationHash,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (subject == address(0) || attester == address(0)) revert InvalidAddress();
        if (attestationHash == bytes32(0)) revert EmptyAttestation();
        require(block.timestamp <= deadline, "Signature expired");

        uint256 currentNonce = nonces[attester]++;
        bytes32 structHash = keccak256(abi.encode(RECORD_ATTESTATION_TYPEHASH, subject, attestationHash, currentNonce, deadline));
        bytes32 hash = _hashTypedDataV4(structHash);
        
        address signer = hash.recover(signature);
        require(signer == attester, "Invalid signature");

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        ds.attestations[subject][attester][attestationHash] = true;

        emit AttestationRecorded(subject, attester, attestationHash);
    }

    function hasAttestation(address subject, address attester, bytes32 attestationHash) external view override returns (bool) {
        if (subject == address(0) || attester == address(0)) return false;

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        return ds.attestations[subject][attester][attestationHash];
    }
}
