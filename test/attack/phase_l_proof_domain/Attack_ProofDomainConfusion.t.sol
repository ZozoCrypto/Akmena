// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {LibTransientProof} from "../../../src/libraries/LibTransientProof.sol";

contract Attack_ProofDomainConfusionTest is Test {
    address internal constant SUBJECT = address(0x2222);
    uint256 internal constant PROOF_ID = 1;
    uint256 internal constant AMOUNT = 1 ether;

    function test_EscrowProofCannotValidateAsPrivacyProof() public {
        LibTransientProof.setEscrowProof(PROOF_ID, SUBJECT, address(0), AMOUNT);

        assertTrue(
            LibTransientProof.verifyEscrowProof(PROOF_ID, SUBJECT, address(0), AMOUNT),
            "exact escrow proof should validate"
        );

        assertFalse(
            LibTransientProof.verifyPrivacyProof(PROOF_ID, SUBJECT, address(0), AMOUNT),
            "CRITICAL: escrow proof crossed into privacy domain"
        );
    }

    function test_PrivacyProofCannotValidateAsEscrowProof() public {
        LibTransientProof.setPrivacyProof(PROOF_ID, SUBJECT, address(0), AMOUNT);

        assertTrue(
            LibTransientProof.verifyPrivacyProof(PROOF_ID, SUBJECT, address(0), AMOUNT),
            "exact privacy proof should validate"
        );

        assertFalse(
            LibTransientProof.verifyEscrowProof(PROOF_ID, SUBJECT, address(0), AMOUNT),
            "CRITICAL: privacy proof crossed into escrow domain"
        );
    }

    function test_SameProofIdRemainsDomainSeparated() public {
        LibTransientProof.setEscrowProof(PROOF_ID, SUBJECT, address(0), AMOUNT);

        LibTransientProof.setPrivacyProof(PROOF_ID, SUBJECT, address(0), AMOUNT);

        assertTrue(LibTransientProof.verifyEscrowProof(PROOF_ID, SUBJECT, address(0), AMOUNT));

        assertTrue(LibTransientProof.verifyPrivacyProof(PROOF_ID, SUBJECT, address(0), AMOUNT));
    }

    function test_EscrowProofBindsSubject() public {
        LibTransientProof.setEscrowProof(PROOF_ID, SUBJECT, address(0), AMOUNT);

        assertFalse(
            LibTransientProof.verifyEscrowProof(PROOF_ID, address(0x3333), address(0), AMOUNT),
            "CRITICAL: escrow proof crossed subject boundary"
        );
    }

    function test_EscrowProofBindsAmount() public {
        LibTransientProof.setEscrowProof(PROOF_ID, SUBJECT, address(0), AMOUNT);

        assertFalse(
            LibTransientProof.verifyEscrowProof(PROOF_ID, SUBJECT, address(0), 2 ether),
            "CRITICAL: escrow proof crossed amount boundary"
        );
    }

    function test_PrivacyProofBindsSubject() public {
        LibTransientProof.setPrivacyProof(PROOF_ID, SUBJECT, address(0), AMOUNT);

        assertFalse(
            LibTransientProof.verifyPrivacyProof(PROOF_ID, address(0x3333), address(0), AMOUNT),
            "CRITICAL: privacy proof crossed subject boundary"
        );
    }

    function test_PrivacyProofBindsAmount() public {
        LibTransientProof.setPrivacyProof(PROOF_ID, SUBJECT, address(0), AMOUNT);

        assertFalse(
            LibTransientProof.verifyPrivacyProof(PROOF_ID, SUBJECT, address(0), 2 ether),
            "CRITICAL: privacy proof crossed amount boundary"
        );
    }
}
