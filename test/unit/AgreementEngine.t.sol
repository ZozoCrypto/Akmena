// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/agreements/AgreementEngine.sol";

contract AgreementEngineTest is Test {
    AgreementEngine engine;

    bytes32 internal constant AGREEMENT_ID = keccak256("agreement-1");
    bytes32 internal constant AGREEMENT_ID_2 = keccak256("agreement-2");

    bytes32 internal constant PROPOSER_AGENT = keccak256("agent-a");
    bytes32 internal constant COUNTERPARTY_AGENT = keccak256("agent-b");

    string internal constant TERMS_URI = "ipfs://agreement";

    function setUp() public {
        engine = new AgreementEngine();
    }

    function testProposeAgreement() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        assertTrue(engine.exists(AGREEMENT_ID));
    }

    function testCannotCreateDuplicateAgreement() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        vm.expectRevert(AgreementEngine.AgreementAlreadyExists.selector);

        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);
    }

    function testCannotCreateAgreementTwiceAfterRead() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        engine.getAgreement(AGREEMENT_ID);

        vm.expectRevert(AgreementEngine.AgreementAlreadyExists.selector);

        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);
    }

    function testDifferentAgreementIdsCanExist() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        engine.propose(AGREEMENT_ID_2, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        assertTrue(engine.exists(AGREEMENT_ID));
        assertTrue(engine.exists(AGREEMENT_ID_2));
    }

    function testCannotCreateAgreementWithEmptyTerms() public {
        vm.expectRevert(AgreementEngine.InvalidTerms.selector);

        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, "");
    }

    function testGetUnknownAgreementReverts() public {
        vm.expectRevert(AgreementEngine.AgreementNotFound.selector);

        engine.getAgreement(AGREEMENT_ID);
    }

    function testAgreementStoredCorrectly() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        IAgreementEngine.Agreement memory agreement = engine.getAgreement(AGREEMENT_ID);

        assertEq(agreement.proposerAgent, PROPOSER_AGENT);
        assertEq(agreement.counterpartyAgent, COUNTERPARTY_AGENT);
        assertEq(agreement.termsURI, TERMS_URI);
    }

    function testAgreementAgentsPersistedCorrectly() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        IAgreementEngine.Agreement memory agreement = engine.getAgreement(AGREEMENT_ID);

        assertEq(agreement.proposerAgent, PROPOSER_AGENT);
        assertEq(agreement.counterpartyAgent, COUNTERPARTY_AGENT);
    }

    function testTermsURIPersistedCorrectly() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        IAgreementEngine.Agreement memory agreement = engine.getAgreement(AGREEMENT_ID);

        assertEq(agreement.termsURI, TERMS_URI);
    }

    function testAgreementStatusStartsAsProposed() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        IAgreementEngine.Agreement memory agreement = engine.getAgreement(AGREEMENT_ID);

        assertEq(uint256(agreement.status), uint256(IAgreementEngine.AgreementStatus.Proposed));
    }

    function testAgreementTimestampSet() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        IAgreementEngine.Agreement memory agreement = engine.getAgreement(AGREEMENT_ID);

        assertGt(agreement.createdAt, 0);
    }

    function testExistsReturnsFalseForUnknownAgreement() public view {
        assertFalse(engine.exists(keccak256("unknown-agreement")));
    }

    function testAcceptAgreement() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        engine.accept(AGREEMENT_ID);

        IAgreementEngine.Agreement memory agreement = engine.getAgreement(AGREEMENT_ID);

        assertEq(uint256(agreement.status), uint256(IAgreementEngine.AgreementStatus.Accepted));

        assertGt(agreement.acceptedAt, 0);
    }

    function testRejectAgreement() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        engine.reject(AGREEMENT_ID);

        IAgreementEngine.Agreement memory agreement = engine.getAgreement(AGREEMENT_ID);

        assertEq(uint256(agreement.status), uint256(IAgreementEngine.AgreementStatus.Rejected));
    }

    function testCompleteAgreement() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        engine.accept(AGREEMENT_ID);
        engine.complete(AGREEMENT_ID);

        IAgreementEngine.Agreement memory agreement = engine.getAgreement(AGREEMENT_ID);

        assertEq(uint256(agreement.status), uint256(IAgreementEngine.AgreementStatus.Completed));

        assertGt(agreement.completedAt, 0);
    }

    function testCannotCompleteBeforeAccept() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        vm.expectRevert(AgreementEngine.InvalidStatusTransition.selector);

        engine.complete(AGREEMENT_ID);
    }

    function testCannotAcceptTwice() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        engine.accept(AGREEMENT_ID);

        vm.expectRevert(AgreementEngine.InvalidStatusTransition.selector);

        engine.accept(AGREEMENT_ID);
    }

    function testCannotRejectAfterAccept() public {
        engine.propose(AGREEMENT_ID, PROPOSER_AGENT, COUNTERPARTY_AGENT, TERMS_URI);

        engine.accept(AGREEMENT_ID);

        vm.expectRevert(AgreementEngine.InvalidStatusTransition.selector);

        engine.reject(AGREEMENT_ID);
    }
}
