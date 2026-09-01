// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CapabilityEngine} from "../../../src/authorization/CapabilityEngine.sol";
import {AttestationEngine} from "../../../src/authorization/AttestationEngine.sol";
import {IIdentity} from "../../../src/identity/IIdentity.sol";
import {Identity} from "../../../src/identity/Identity.sol";

contract Attack_AuthorizationPrimitivesTest is Test {
    CapabilityEngine internal capabilities;
    AttestationEngine internal attestations;
    Identity internal victimIdentity;

    address internal victim = address(0x1111);
    address internal attacker = address(0x2222);
    address internal trustedVerifier = address(0x3333);

    bytes32 internal constant PRIVILEGED =
        keccak256("akmena.capability.privileged");

    bytes32 internal constant ATTESTATION =
        keccak256("akmena.attestation.approved");

    function setUp() public {
        capabilities = new CapabilityEngine();
        attestations = new AttestationEngine();

        victimIdentity = new Identity();

        victimIdentity.initialize(
            1,
            victim,
            IIdentity.IdentityType.Machine,
            ""
        );
    }

    function test_Attack_AnyoneCanGrantCapabilityToVictim() public {
        vm.prank(attacker);

        vm.expectRevert(
            CapabilityEngine.UnauthorizedCapabilityMutation.selector
        );

        capabilities.grantCapability(
            address(victimIdentity),
            PRIVILEGED
        );

        assertFalse(
            capabilities.hasCapability(
                address(victimIdentity),
                PRIVILEGED
            ),
            "CRITICAL: attacker granted victim capability"
        );
    }

    function test_Attack_AnyoneCanRevokeVictimCapability() public {
        vm.prank(victim);

        capabilities.grantCapability(
            address(victimIdentity),
            PRIVILEGED
        );

        vm.prank(attacker);

        vm.expectRevert(
            CapabilityEngine.UnauthorizedCapabilityMutation.selector
        );

        capabilities.revokeCapability(
            address(victimIdentity),
            PRIVILEGED
        );

        assertTrue(
            capabilities.hasCapability(
                address(victimIdentity),
                PRIVILEGED
            ),
            "CRITICAL: attacker revoked victim capability"
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
