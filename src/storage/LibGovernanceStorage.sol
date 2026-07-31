// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ActionType, ProtocolAction, ProposalState} from "../governance/IGovernance.sol";

library LibGovernanceStorage {
    bytes32 internal constant GOVERNANCE_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("akmena.storage.governance")) - 1)) & ~bytes32(uint256(31));

    struct GovernanceParams {
        uint256 proposalThreshold;
        uint256 quorumBps;
        uint256 votingPeriodBlocks;
        uint256 votingDelayBlocks;
        uint256 timelockDelay;
        uint256 minTimelockDelay;
        uint256 maxTimelockDelay;
    }

    struct ProposalRecord {
        bytes32 id;
        address proposer;
        uint256 snapshotBlock;
        uint256 voteStart;
        uint256 voteEnd;
        uint256 yesVotes;
        uint256 noVotes;
        bytes32 adrHash;
        bytes32 proposalHash; // Immutable hash passed to Timelock
        string title;
        string descriptionURI;
    }

    struct GovernanceStorage {
        GovernanceParams params;
        mapping(bytes32 => ProposalRecord) proposals;
        mapping(bytes32 => mapping(address => bool)) hasVoted;
    }

    function governanceStorage() internal pure returns (GovernanceStorage storage gs) {
        bytes32 position = GOVERNANCE_STORAGE_POSITION;
        assembly {
            gs.slot := position
        }
    }
}
