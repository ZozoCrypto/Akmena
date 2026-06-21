// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IReputationEngine.sol";

/// @title Akmena Reputation Engine
/// @notice Maintains protocol reputation records for agents.
contract ReputationEngine is IReputationEngine {
    error InvalidPoints();

    mapping(bytes32 => Reputation) internal reputations;

    function reward(bytes32 agentId, uint256 points) external {
        if (points == 0) {
            revert InvalidPoints();
        }

        reputations[agentId].score += points;

        emit ReputationUpdated(agentId, reputations[agentId].score);
    }

    function penalize(bytes32 agentId, uint256 points) external {
        if (points == 0) {
            revert InvalidPoints();
        }

        Reputation storage reputation = reputations[agentId];

        if (points >= reputation.score) {
            reputation.score = 0;
        } else {
            reputation.score -= points;
        }

        emit ReputationUpdated(agentId, reputation.score);
    }

    function recordCompletion(bytes32 agentId) external {
        Reputation storage reputation = reputations[agentId];

        reputation.completedAgreements++;

        emit CompletionRecorded(agentId, reputation.completedAgreements);
    }

    function getReputation(bytes32 agentId) external view returns (Reputation memory) {
        return reputations[agentId];
    }
}
