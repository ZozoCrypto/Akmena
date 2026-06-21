// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Akmena Reputation Engine Interface
/// @notice Tracks agent reputation and protocol participation.
interface IReputationEngine {
    struct Reputation {
        uint256 score;
        uint64 completedAgreements;
        uint64 acceptedAgreements;
        uint64 rejectedAgreements;
    }

    event ReputationUpdated(bytes32 indexed agentId, uint256 score);

    event CompletionRecorded(bytes32 indexed agentId, uint64 completedAgreements);

    function reward(bytes32 agentId, uint256 points) external;

    function penalize(bytes32 agentId, uint256 points) external;

    function recordCompletion(bytes32 agentId) external;

    function getReputation(bytes32 agentId) external view returns (Reputation memory);
}
