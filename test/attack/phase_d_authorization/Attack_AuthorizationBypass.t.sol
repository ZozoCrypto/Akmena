// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DelegationEngine} from "../../../src/authorization/DelegationEngine.sol";
import {AttestationEngine} from "../../../src/authorization/AttestationEngine.sol";
import {LibStorage} from "../../../src/storage/LibStorage.sol";

contract Attack_AuthorizationBypassTest is Test {
    DelegationEngine internal delegationEngine;
    AttestationEngine internal attestationEngine;

    address internal attacker = address(0xBEEF);
    address internal victim = address(0xCAFE);

    function setUp() public {
        delegationEngine = new DelegationEngine();
        attestationEngine = new AttestationEngine();
    }

    function test_Attack_DirectDelegationHijack() public {
        // 1. Attacker calls DelegationEngine directly
        vm.prank(attacker);
        delegationEngine.setDelegate(attacker, true);

        // 2. Verify that attacker successfully made themselves a delegate of themselves
        bool isDel = delegationEngine.isDelegate(attacker, attacker);
        assertTrue(isDel, "Attacker successfully set delegate status.");
    }

    function test_Attack_AttestationForgery() public {
        bytes32 fakeAttestationHash = keccak256("fake-kyc-passed");

        // 1. Attacker attests on behalf of themselves (or tries to forge status)
        vm.prank(attacker);
        attestationEngine.recordAttestation(attacker, fakeAttestationHash);

        // 2. Verify the attestation is recorded
        bool hasAtt = attestationEngine.hasAttestation(attacker, attacker, fakeAttestationHash);
        assertTrue(hasAtt, "Attacker successfully recorded arbitrary attestation.");

        // 3. The Core Flaw: Because AttestationEngine uses msg.sender as the attester,
        // if any contract or workflow calls recordAttestation without strict caller validation,
        // the calling contract becomes the trusted attester for arbitrary subjects.
    }
}
