// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AgreementEngine} from "../../src/autonomous/AgreementEngine.sol";

contract AttackWave1_TemporalStateTest is Test {
    AgreementEngine internal agreementEngine;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        agreementEngine = new AgreementEngine();
    }

    function test_Attack_AgreementDoubleExecutionExploit() public {
        bytes32 agreementId = bytes32("AGREEMENT_DRAIN");
        bytes32 termsHash = keccak256("TERMS_V1");
        uint256 validUntil = block.timestamp + 1000;

        vm.prank(alice);
        agreementEngine.createAgreement(agreementId, bob, termsHash, validUntil);

        // Execute first time (Valid)
        vm.prank(bob);
        agreementEngine.executeAgreement(agreementId);

        // EXPLOIT ATTEMPT: Execute a second time. 
        // MUST revert now that we patched the zero-day!
        vm.expectRevert(bytes("AgreementAlreadyExecuted"));
        vm.prank(bob);
        agreementEngine.executeAgreement(agreementId);
    }
}
