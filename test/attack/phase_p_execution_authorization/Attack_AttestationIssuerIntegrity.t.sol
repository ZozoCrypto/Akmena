// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {
    AttestationEngine
} from "../../../src/authorization/AttestationEngine.sol";


contract AttackAttestationIssuerIntegrityTest is Test {
    AttestationEngineHarness internal attestation;

    uint256 internal constant ISSUER_KEY = 0xA11CE;
    uint256 internal constant ATTACKER_KEY = 0xBEEF;

    address internal issuer;
    address internal attacker;

    address internal subject =
        address(0xCCCC);

    address internal substitutedSubject =
        address(0xDDDD);

    bytes32 internal constant CLAIM =
        keccak256("claim");

    function setUp() public {
        attestation =
            new AttestationEngineHarness();

        issuer =
            vm.addr(ISSUER_KEY);

        attacker =
            vm.addr(ATTACKER_KEY);
    }


    function test_DirectAttestationAttributesIssuerToCaller()
        public
    {
        vm.prank(attacker);

        attestation.recordAttestation(
            subject,
            CLAIM
        );

        assertTrue(
            attestation.hasAttestation(
                subject,
                attacker,
                CLAIM
            )
        );

        assertFalse(
            attestation.hasAttestation(
                subject,
                issuer,
                CLAIM
            )
        );
    }


    function test_TypedAttestationBindsSubject()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        bytes32 typeHash =
            keccak256(
                "RecordAttestation(address subject,bytes32 attestationHash,uint256 nonce,uint256 deadline)"
            );

        bytes32 structHash =
            keccak256(
                abi.encode(
                    typeHash,
                    subject,
                    CLAIM,
                    0,
                    deadline
                )
            );

        bytes32 digest =
            attestation.exposedHashTypedDataV4(
                structHash
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                ISSUER_KEY,
                digest
            );

        bytes memory signature =
            abi.encodePacked(
                r,
                s,
                v
            );

        vm.expectRevert();

        attestation.recordAttestationTyped(
            issuer,
            substitutedSubject,
            CLAIM,
            deadline,
            signature
        );
    }


    function test_TypedAttestationBindsClaimHash()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        bytes32 typeHash =
            keccak256(
                "RecordAttestation(address subject,bytes32 attestationHash,uint256 nonce,uint256 deadline)"
            );

        bytes32 structHash =
            keccak256(
                abi.encode(
                    typeHash,
                    subject,
                    CLAIM,
                    0,
                    deadline
                )
            );

        bytes32 digest =
            attestation.exposedHashTypedDataV4(
                structHash
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                ISSUER_KEY,
                digest
            );

        bytes memory signature =
            abi.encodePacked(
                r,
                s,
                v
            );

        vm.expectRevert();

        attestation.recordAttestationTyped(
            issuer,
            subject,
            keccak256("different-claim"),
            deadline,
            signature
        );
    }


    function test_TypedAttestationCannotReplay()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        bytes32 typeHash =
            keccak256(
                "RecordAttestation(address subject,bytes32 attestationHash,uint256 nonce,uint256 deadline)"
            );

        bytes32 structHash =
            keccak256(
                abi.encode(
                    typeHash,
                    subject,
                    CLAIM,
                    0,
                    deadline
                )
            );

        bytes32 digest =
            attestation.exposedHashTypedDataV4(
                structHash
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                ISSUER_KEY,
                digest
            );

        bytes memory signature =
            abi.encodePacked(
                r,
                s,
                v
            );

        attestation.recordAttestationTyped(
            issuer,
            subject,
            CLAIM,
            deadline,
            signature
        );

        vm.expectRevert();

        attestation.recordAttestationTyped(
            issuer,
            subject,
            CLAIM,
            deadline,
            signature
        );
    }
}


// Harness exposes OpenZeppelin's internal EIP-712 digest builder.
contract AttestationEngineHarness is AttestationEngine {
    function exposedHashTypedDataV4(
        bytes32 structHash
    )
        external
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(structHash);
    }
}
