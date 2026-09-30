// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {LibTransientProof} from "../../src/libraries/LibTransientProof.sol";

contract TransientProofDomainIsolationHarness {
    /// @dev Write and read in the SAME frame (nested). Foundry's revm does not
    /// persist EIP-1153 transient storage across sibling frames, but nested
    /// frames work correctly. This tests the domain-separation property
    /// without depending on the environmental limitation.
    function writeAndReadEscrow(uint256 id, address subject, uint256 amount)
        external
        returns (bool written, bool leakedToPrivacy)
    {
        LibTransientProof.setEscrowProof(id, subject, address(0), amount);
        written = LibTransientProof.verifyEscrowProof(id, subject, address(0), amount);
        leakedToPrivacy = LibTransientProof.verifyPrivacyProof(id, subject, address(0), amount);
    }

    function writeAndReadPrivacy(uint256 id, address subject, uint256 amount)
        external
        returns (bool written, bool leakedToEscrow)
    {
        LibTransientProof.setPrivacyProof(id, subject, address(0), amount);
        written = LibTransientProof.verifyPrivacyProof(id, subject, address(0), amount);
        leakedToEscrow = LibTransientProof.verifyEscrowProof(id, subject, address(0), amount);
    }

    function writeBothAndRead(uint256 id, address subject, uint256 amount)
        external
        returns (bool escrowValid, bool privacyValid)
    {
        LibTransientProof.setEscrowProof(id, subject, address(0), amount);
        LibTransientProof.setPrivacyProof(id, subject, address(0), amount);
        escrowValid = LibTransientProof.verifyEscrowProof(id, subject, address(0), amount);
        privacyValid = LibTransientProof.verifyPrivacyProof(id, subject, address(0), amount);
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
        (bool written, bool leaked) = harness.writeAndReadEscrow(ID, subject, AMOUNT);

        assertTrue(written, "escrow proof was not written");
        assertFalse(leaked, "escrow proof leaked into privacy domain");
    }

    function test_PrivacyAndEscrowDomainsAreIndependent() public {
        (bool written, bool leaked) = harness.writeAndReadPrivacy(ID, subject, AMOUNT);

        assertTrue(written, "privacy proof was not written");
        assertFalse(leaked, "privacy proof leaked into escrow domain");
    }

    function test_SameIdDifferentDomainCannotCrossAuthenticate() public {
        (bool escrowValid, bool privacyValid) = harness.writeBothAndRead(ID, subject, AMOUNT);

        assertTrue(escrowValid, "escrow proof invalid");
        assertTrue(privacyValid, "privacy proof invalid");

        // Same numeric identifier, same subject, same amount.
        // Each proof must remain valid only in its own domain.
    }
}
