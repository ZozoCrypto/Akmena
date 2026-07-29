// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {VerificationEngine} from "../../src/authorization/VerificationEngine.sol";
import {IVerificationEngine} from "../../src/authorization/IVerificationEngine.sol";
import {AttestationEngine} from "../../src/authorization/AttestationEngine.sol";
import {IAttestationEngine} from "../../src/authorization/IAttestationEngine.sol";

contract VerificationAndAttestationTest is Test {
    VerificationEngine public verificationEngine;
    AttestationEngine public attestationEngine;

    address public subject = address(0x333);
    address public attester = address(0x444);
    bytes32 public sampleHash = keccak256("ATTESTATION_DATA");

    function setUp() public {
        verificationEngine = new VerificationEngine();
        attestationEngine = new AttestationEngine();
    }

    function test_SetAndCheckVerification() public {
        vm.expectEmit(true, true, true, true);
        emit IVerificationEngine.IdentityVerified(subject, true);

        verificationEngine.setVerification(subject, true);
        assertTrue(verificationEngine.isVerified(subject), "Subject should be verified");
    }

    function test_RecordAndCheckAttestation() public {
        vm.prank(attester);
        vm.expectEmit(true, true, true, true);
        emit IAttestationEngine.AttestationRecorded(subject, attester, sampleHash);

        attestationEngine.recordAttestation(subject, sampleHash);
        assertTrue(attestationEngine.hasAttestation(subject, attester, sampleHash), "Attestation should exist");
    }

    function test_RevertWhen_SettingZeroAddressVerification() public {
        vm.expectRevert(IVerificationEngine.InvalidAddress.selector);
        verificationEngine.setVerification(address(0), true);
    }

    function test_RevertWhen_RecordingEmptyAttestation() public {
        vm.prank(attester);
        vm.expectRevert(IAttestationEngine.EmptyAttestation.selector);
        attestationEngine.recordAttestation(subject, bytes32(0));
    }
}
