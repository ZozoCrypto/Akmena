// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ActionType, ProtocolAction, ProposalState, IVotes, IAkmenaTimelock} from "./IGovernance.sol";
import {LibGovernanceStorage} from "../storage/LibGovernanceStorage.sol";

contract AkmenaGovernor {
    IVotes public immutable token;
    IAkmenaTimelock public timelock;

    event ProposalCreated(bytes32 indexed proposalId, address indexed proposer, string title, bytes32 adrHash, uint256 snapshotBlock);
    event VoteCast(address indexed voter, bytes32 indexed proposalId, bool support, uint256 weight);

    error InsufficientProposalPower();
    error InvalidState();
    error AlreadyVoted();

    constructor(address _token) {
        token = IVotes(_token);
        LibGovernanceStorage.GovernanceStorage storage gs = LibGovernanceStorage.governanceStorage();
        gs.params.proposalThreshold = 1_000_000 * 10**18;
        gs.params.quorumBps = 400;
        gs.params.votingPeriodBlocks = 50400;
        gs.params.votingDelayBlocks = 1;
        gs.params.timelockDelay = 3 days;
    }

    function setTimelock(address _timelock) external {
        require(address(timelock) == address(0), "Timelock already set");
        timelock = IAkmenaTimelock(_timelock);
    }

    function propose(ProtocolAction[] calldata actions, string calldata title, string calldata descriptionURI, bytes32 adrHash) external returns (bytes32) {
        LibGovernanceStorage.GovernanceStorage storage gs = LibGovernanceStorage.governanceStorage();
        
        uint256 snapshotBlock = block.number - gs.params.votingDelayBlocks;
        if (token.getPastVotes(msg.sender, snapshotBlock) < gs.params.proposalThreshold) {
            revert InsufficientProposalPower();
        }

        bytes32 proposalId = keccak256(abi.encode(msg.sender, block.number, adrHash, actions));
        bytes32 proposalHash = keccak256(abi.encode(actions, adrHash));

        LibGovernanceStorage.ProposalRecord storage p = gs.proposals[proposalId];
        require(p.id == bytes32(0), "Proposal collision");

        p.id = proposalId;
        p.proposer = msg.sender;
        p.snapshotBlock = snapshotBlock;
        p.voteStart = block.number + gs.params.votingDelayBlocks;
        p.voteEnd = p.voteStart + gs.params.votingPeriodBlocks;
        p.adrHash = adrHash;
        p.proposalHash = proposalHash;
        p.title = title;
        p.descriptionURI = descriptionURI;

        emit ProposalCreated(proposalId, msg.sender, title, adrHash, snapshotBlock);
        return proposalId;
    }

    function castVote(bytes32 proposalId, bool support) external {
        if (state(proposalId) != ProposalState.Active) revert InvalidState();

        LibGovernanceStorage.GovernanceStorage storage gs = LibGovernanceStorage.governanceStorage();
        if (gs.hasVoted[proposalId][msg.sender]) revert AlreadyVoted();

        LibGovernanceStorage.ProposalRecord storage p = gs.proposals[proposalId];
        uint256 weight = token.getPastVotes(msg.sender, p.snapshotBlock);

        gs.hasVoted[proposalId][msg.sender] = true;

        if (support) p.yesVotes += weight;
        else p.noVotes += weight;

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    function queue(bytes32 proposalId) external {
        if (state(proposalId) != ProposalState.Succeeded) revert InvalidState();

        LibGovernanceStorage.GovernanceStorage storage gs = LibGovernanceStorage.governanceStorage();
        LibGovernanceStorage.ProposalRecord storage p = gs.proposals[proposalId];

        uint256 eta = block.timestamp + gs.params.timelockDelay;
        timelock.queue(proposalId, eta, p.proposalHash);
    }

    function state(bytes32 proposalId) public view returns (ProposalState) {
        LibGovernanceStorage.GovernanceStorage storage gs = LibGovernanceStorage.governanceStorage();
        LibGovernanceStorage.ProposalRecord memory p = gs.proposals[proposalId];

        if (p.id == bytes32(0)) revert InvalidState();

        // 100% Layer Sovereignty: Governor queries Timelock for execution status
        (uint256 eta, bool executed, bool canceled) = timelock.getProposalStatus(proposalId);

        if (canceled) return ProposalState.Canceled;
        if (executed) return ProposalState.Executed;

        if (block.number <= p.voteStart) return ProposalState.Pending;
        if (block.number <= p.voteEnd) return ProposalState.Active;

        uint256 quorumRequired = (token.totalSupply() * gs.params.quorumBps) / 10000;

        if (p.yesVotes + p.noVotes < quorumRequired || p.yesVotes <= p.noVotes) return ProposalState.Defeated;
        if (eta == 0) return ProposalState.Succeeded;
        if (block.timestamp >= eta + 14 days) return ProposalState.Expired;

        return ProposalState.Queued;
    }
}
