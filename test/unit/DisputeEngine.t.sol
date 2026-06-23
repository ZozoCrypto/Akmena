// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import "../../src/disputes/DisputeEngine.sol";
import "../../src/interfaces/IDisputeEngine.sol";

contract DisputeEngineTest is Test {
    DisputeEngine engine;

    bytes32 internal constant DISPUTE_ID = keccak256("dispute-1");

    bytes32 internal constant AGREEMENT_ID = keccak256("agreement-1");

    string internal constant EVIDENCE = "ipfs://evidence";

    function setUp() public {
        engine = new DisputeEngine();
    }

    function testOpenDispute() public {
        engine.openDispute(DISPUTE_ID, AGREEMENT_ID, EVIDENCE);

        assertTrue(engine.exists(DISPUTE_ID));
    }

    function testDisputeStoredCorrectly() public {
        engine.openDispute(DISPUTE_ID, AGREEMENT_ID, EVIDENCE);

        IDisputeEngine.Dispute memory dispute = engine.getDispute(DISPUTE_ID);

        assertEq(dispute.id, DISPUTE_ID);
        assertEq(dispute.agreementId, AGREEMENT_ID);
        assertEq(dispute.claimant, address(this));
    }

    function testDisputeStartsOpen() public {
        engine.openDispute(DISPUTE_ID, AGREEMENT_ID, EVIDENCE);

        IDisputeEngine.Dispute memory dispute = engine.getDispute(DISPUTE_ID);

        assertEq(uint256(dispute.status), uint256(IDisputeEngine.DisputeStatus.Open));
    }

    function testEvidencePersisted() public {
        engine.openDispute(DISPUTE_ID, AGREEMENT_ID, EVIDENCE);

        IDisputeEngine.Dispute memory dispute = engine.getDispute(DISPUTE_ID);

        assertEq(dispute.evidenceURI, EVIDENCE);
    }

    function testResolveDispute() public {
        engine.openDispute(DISPUTE_ID, AGREEMENT_ID, EVIDENCE);

        engine.resolveDispute(DISPUTE_ID);

        IDisputeEngine.Dispute memory dispute = engine.getDispute(DISPUTE_ID);

        assertEq(uint256(dispute.status), uint256(IDisputeEngine.DisputeStatus.Resolved));
    }

    function testRejectDispute() public {
        engine.openDispute(DISPUTE_ID, AGREEMENT_ID, EVIDENCE);

        engine.rejectDispute(DISPUTE_ID);

        IDisputeEngine.Dispute memory dispute = engine.getDispute(DISPUTE_ID);

        assertEq(uint256(dispute.status), uint256(IDisputeEngine.DisputeStatus.Rejected));
    }

    function testCannotCreateDuplicateDispute() public {
        engine.openDispute(DISPUTE_ID, AGREEMENT_ID, EVIDENCE);

        vm.expectRevert(DisputeEngine.DisputeAlreadyExists.selector);

        engine.openDispute(DISPUTE_ID, AGREEMENT_ID, EVIDENCE);
    }

    function testCannotUseEmptyEvidence() public {
        vm.expectRevert(DisputeEngine.EmptyEvidence.selector);

        engine.openDispute(DISPUTE_ID, AGREEMENT_ID, "");
    }

    function testCannotResolveTwice() public {
        engine.openDispute(DISPUTE_ID, AGREEMENT_ID, EVIDENCE);

        engine.resolveDispute(DISPUTE_ID);

        vm.expectRevert(DisputeEngine.AlreadyFinalized.selector);

        engine.resolveDispute(DISPUTE_ID);
    }

    function testGetUnknownDisputeReverts() public {
        vm.expectRevert(DisputeEngine.DisputeNotFound.selector);

        engine.getDispute(DISPUTE_ID);
    }
}
