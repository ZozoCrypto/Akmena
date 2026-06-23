// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentMatchingEngine.sol";

contract AgentMatchingEngine is IAgentMatchingEngine {
    error AgentAlreadyScored();
    error InvalidScore();
    error MatchNotFound();

    mapping(bytes32 => Match) internal matches;

    function setScore(bytes32 agentId, uint256 score) external {
        if (exists(agentId)) {
            revert AgentAlreadyScored();
        }

        if (score == 0) {
            revert InvalidScore();
        }

        matches[agentId] = Match({agentId: agentId, score: score});

        emit AgentScored(agentId, score);
    }

    function getScore(bytes32 agentId) external view returns (uint256) {
        if (!exists(agentId)) {
            revert MatchNotFound();
        }

        return matches[agentId].score;
    }

    function getMatch(bytes32 agentId) external view returns (Match memory) {
        if (!exists(agentId)) {
            revert MatchNotFound();
        }

        return matches[agentId];
    }

    function exists(bytes32 agentId) public view returns (bool) {
        return matches[agentId].agentId != bytes32(0);
    }
}
