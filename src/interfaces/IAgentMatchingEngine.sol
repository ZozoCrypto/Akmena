// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentMatchingEngine {
    struct Match {
        bytes32 agentId;
        uint256 score;
    }

    event AgentScored(bytes32 indexed agentId, uint256 score);

    function setScore(bytes32 agentId, uint256 score) external;

    function getScore(bytes32 agentId) external view returns (uint256);

    function getMatch(bytes32 agentId) external view returns (Match memory);

    function exists(bytes32 agentId) external view returns (bool);
}
