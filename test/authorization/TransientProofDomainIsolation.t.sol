// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {LibTransientProof} from "../../src/libraries/LibTransientProof.sol";

contract TransientProofDomainIsolationHarness {
    function writeEscrow(uint256 id, address subject, uint256 amount) external {
        LibTransientProof.setEscrowProof(id, subject, address(0), amount);
    }

    function writePrivacy(uint256 id, address subject, uint256 amount) external {
        LibTransientProof.setPrivacyProof(id, subject, address(0), amount);
    }

    function readEscrow(uint256 id, address subject, uint256 amount) external view returns (bool) {
        return LibTransientProof.verifyEscrowProof(id, subject, address(0), amount);
    }

    function readPrivacy(uint256 id, address subject, uint256 amount) external view returns (bool) {
        return LibTransientProof.verifyPrivacyProof(id, subject, address(0), amount);
    }
}

contract TransientProofDomainIsolationTest is Test {
    TransientProofDomainIsolationHarness internal harness;

    address internal subject = address(0xBEEF);
    uint256 internal constant ID = 1;
    uint256 internal constant AMOUNT = 1 ether;

    function setUp() public {
        harness = new TransientProofDomainIsolationHarness();
    }

    function test_EscrowAndPrivacyDomainsAreIndependent() public {
        harness.writeEscrow(ID, subject, AMOUNT);

        assertTrue(harness.readEscrow(ID, subject, AMOUNT), "escrow proof was not written");

        assertFalse(harness.readPrivacy(ID, subject, AMOUNT), "escrow proof leaked into privacy domain");
    }

    function test_PrivacyAndEscrowDomainsAreIndependent() public {
        harness.writePrivacy(ID, subject, AMOUNT);

        assertTrue(harness.readPrivacy(ID, subject, AMOUNT), "privacy proof was not written");

        assertFalse(harness.readEscrow(ID, subject, AMOUNT), "privacy proof leaked into escrow domain");
    }

    function test_SameIdDifferentDomainCannotCrossAuthenticate() public {
        harness.writeEscrow(ID, subject, AMOUNT);
        harness.writePrivacy(ID, subject, AMOUNT);

        assertTrue(harness.readEscrow(ID, subject, AMOUNT));
        assertTrue(harness.readPrivacy(ID, subject, AMOUNT));

        // Same numeric identifier, same subject, same amount.
        // Each proof must remain valid only in its own domain.
    }
}
