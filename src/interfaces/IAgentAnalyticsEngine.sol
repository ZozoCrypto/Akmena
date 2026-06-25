// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentAnalyticsEngine {
    struct Analytics {
        bytes32 agentId;
        uint256 completedTasks;
        uint256 totalEarned;
        uint256 reputationScore;
        uint256 averageRating;
        uint256 updatedAt;
    }

    event AnalyticsUpdated(
        bytes32 indexed agentId,
        uint256 completedTasks,
        uint256 totalEarned,
        uint256 reputationScore,
        uint256 averageRating
    );

    function updateAnalytics(
        bytes32 agentId,
        uint256 completedTasks,
        uint256 totalEarned,
        uint256 reputationScore,
        uint256 averageRating
    ) external;

    function getAnalytics(bytes32 agentId) external view returns (Analytics memory);

    function hasAnalytics(bytes32 agentId) external view returns (bool);
}
