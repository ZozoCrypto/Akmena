// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentGovernanceEngine.sol";

contract AgentGovernanceEngine is IAgentGovernanceEngine {
    error ProposalAlreadyExists();
    error ProposalNotFound();
    error EmptyDescription();
    error InvalidStatus();

    mapping(bytes32 => Proposal) internal proposals;
    mapping(bytes32 => bool) internal proposalExists;

    function createProposal(bytes32 proposalId, string calldata description) external {
        if (proposalExists[proposalId]) {
            revert ProposalAlreadyExists();
        }

        if (bytes(description).length == 0) {
            revert EmptyDescription();
        }

        proposals[proposalId] = Proposal({
            proposalId: proposalId, description: description, status: ProposalStatus.Active, createdAt: block.timestamp
        });

        proposalExists[proposalId] = true;

        emit ProposalCreated(proposalId, description);
    }

    function executeProposal(bytes32 proposalId) external {
        if (!proposalExists[proposalId]) {
            revert ProposalNotFound();
        }

        Proposal storage proposal = proposals[proposalId];

        if (proposal.status != ProposalStatus.Active) {
            revert InvalidStatus();
        }

        proposal.status = ProposalStatus.Executed;

        emit ProposalExecuted(proposalId);
    }

    function rejectProposal(bytes32 proposalId) external {
        if (!proposalExists[proposalId]) {
            revert ProposalNotFound();
        }

        Proposal storage proposal = proposals[proposalId];

        if (proposal.status != ProposalStatus.Active) {
            revert InvalidStatus();
        }

        proposal.status = ProposalStatus.Rejected;

        emit ProposalRejected(proposalId);
    }

    function getProposal(bytes32 proposalId) external view returns (Proposal memory) {
        if (!proposalExists[proposalId]) {
            revert ProposalNotFound();
        }

        return proposals[proposalId];
    }

    function exists(bytes32 proposalId) external view returns (bool) {
        return proposalExists[proposalId];
    }
}
