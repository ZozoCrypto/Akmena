// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CapabilityEngine} from "../../../src/authorization/CapabilityEngine.sol";
import {VerificationEngine} from "../../../src/authorization/VerificationEngine.sol";
import {AttestationEngine} from "../../../src/authorization/AttestationEngine.sol";

contract Attack_AuthorizationPrimitivesTest is Test {
    CapabilityEngine internal capabilities;
    VerificationEngine internal verification;
    AttestationEngine internal attestations;

    address internal victim = address(0x1111);
    address internal attacker = address(0x2222);
    address internal trustedVerifier = address(0x3333);

    bytes32 internal constant PRIVILEGED =
        keccak256("akmena.capability.privileged");

    bytes32 internal constant ATTESTATION =
        keccak256("akmena.attestation.approved");

    function setUp() public {
        capabilities = new CapabilityEngine();
        verification = new VerificationEngine();
        attestations = new AttestationEngine();
    }

    function test_Attack_AnyoneCanGrantCapabilityToVictim() public {
        vm.prank(attacker);

        capabilities.grantCapability(
            victim,
            PRIVILEGED
        );

        assertTrue(
            capabilities.hasCapability(victim, PRIVILEGED),
            "EXPECTED VULNERABILITY: attacker granted victim capability"
        );
    }

    function test_Attack_AnyoneCanRevokeVictimCapability() public {
        vm.prank(victim);

        capabilities.grantCapability(
            victim,
            PRIVILEGED
        );

        vm.prank(attacker);

        capabilities.revokeCapability(
            victim,
            PRIVILEGED
        );

        assertFalse(
            capabilities.hasCapability(victim, PRIVILEGED),
            "EXPECTED VULNERABILITY: attacker revoked victim capability"
        );
    }

    function test_Attack_AnyoneCanForgeVerification() public {
        vm.prank(attacker);

        verification.setVerification(
            victim,
            true
        );

        assertTrue(
            verification.isVerified(victim),
            "EXPECTED VULNERABILITY: attacker forged verification"
        );
    }

    function test_Attack_AnyoneCanRevokeVerification() public {
        vm.prank(trustedVerifier);

        verification.setVerification(
            victim,
            true
        );

        vm.prank(attacker);

        verification.setVerification(
            victim,
            false
        );

        assertFalse(
            verification.isVerified(victim),
            "EXPECTED VULNERABILITY: attacker revoked verification"
        );
    }

    function test_Attack_AnyoneCanCreateSelfAttestation() public {
        vm.prank(attacker);

        attestations.recordAttestation(
            victim,
            ATTESTATION
        );

        assertTrue(
            attestations.hasAttestation(
                victim,
                attacker,
                ATTESTATION
            ),
            "EXPECTED VULNERABILITY: attacker created attestation"
        );
    }
}
