// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAttestationEngine {
    event AttestationRecorded(address indexed subject, address indexed attester, bytes32 indexed attestationHash);

    error InvalidAddress();
    error EmptyAttestation();

    function recordAttestation(address subject, bytes32 attestationHash) external;
    function hasAttestation(address subject, address attester, bytes32 attestationHash) external view returns (bool);
}
