// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/governance/AgentGovernanceEngine.sol";

contract AgentGovernanceEngineTest is Test {
    AgentGovernanceEngine engine;

    bytes32 constant PROPOSAL_A = keccak256("proposal-a");
    bytes32 constant PROPOSAL_B = keccak256("proposal-b");

    function setUp() public {
        engine = new AgentGovernanceEngine();
    }

    function testCreateProposal() public {
        engine.createProposal(PROPOSAL_A, "Increase staking rewards");

        assertTrue(engine.exists(PROPOSAL_A));
    }

    function testCannotCreateDuplicateProposal() public {
        engine.createProposal(PROPOSAL_A, "Proposal");

        vm.expectRevert();

        engine.createProposal(PROPOSAL_A, "Proposal");
    }

    function testCannotCreateEmptyDescription() public {
        vm.expectRevert();

        engine.createProposal(PROPOSAL_A, "");
    }

    function testExecuteProposal() public {
        engine.createProposal(PROPOSAL_A, "Proposal");

        engine.executeProposal(PROPOSAL_A);

        IAgentGovernanceEngine.Proposal memory proposal = engine.getProposal(PROPOSAL_A);

        assertEq(uint256(proposal.status), uint256(IAgentGovernanceEngine.ProposalStatus.Executed));
    }

    function testRejectProposal() public {
        engine.createProposal(PROPOSAL_A, "Proposal");

        engine.rejectProposal(PROPOSAL_A);

        IAgentGovernanceEngine.Proposal memory proposal = engine.getProposal(PROPOSAL_A);

        assertEq(uint256(proposal.status), uint256(IAgentGovernanceEngine.ProposalStatus.Rejected));
    }

    function testCannotExecuteTwice() public {
        engine.createProposal(PROPOSAL_A, "Proposal");

        engine.executeProposal(PROPOSAL_A);

        vm.expectRevert();

        engine.executeProposal(PROPOSAL_A);
    }

    function testTimestampSet() public {
        engine.createProposal(PROPOSAL_A, "Proposal");

        IAgentGovernanceEngine.Proposal memory proposal = engine.getProposal(PROPOSAL_A);

        assertGt(proposal.createdAt, 0);
    }

    function testProposalStoredCorrectly() public {
        engine.createProposal(PROPOSAL_A, "Proposal");

        IAgentGovernanceEngine.Proposal memory proposal = engine.getProposal(PROPOSAL_A);

        assertEq(proposal.proposalId, PROPOSAL_A);
        assertEq(proposal.description, "Proposal");
    }

    function testUnknownProposalReturnsFalse() public view {
        assertFalse(engine.exists(PROPOSAL_B));
    }
}
