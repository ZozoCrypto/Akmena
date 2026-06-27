// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentGovernanceEngine {
    enum ProposalStatus {
        Active,
        Executed,
        Rejected
    }

    struct Proposal {
        bytes32 proposalId;
        string description;
        ProposalStatus status;
        uint256 createdAt;
    }

    event ProposalCreated(bytes32 indexed proposalId, string description);

    event ProposalExecuted(bytes32 indexed proposalId);

    event ProposalRejected(bytes32 indexed proposalId);

    function createProposal(bytes32 proposalId, string calldata description) external;

    function executeProposal(bytes32 proposalId) external;

    function rejectProposal(bytes32 proposalId) external;

    function getProposal(bytes32 proposalId) external view returns (Proposal memory);

    function exists(bytes32 proposalId) external view returns (bool);
}
