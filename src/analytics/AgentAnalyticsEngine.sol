// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentAnalyticsEngine.sol";

contract AgentAnalyticsEngine is IAgentAnalyticsEngine {
    mapping(bytes32 => Analytics) internal analytics;

    function updateAnalytics(
        bytes32 agentId,
        uint256 completedTasks,
        uint256 totalEarned,
        uint256 reputationScore,
        uint256 averageRating
    ) external {
        analytics[agentId] = Analytics({
            agentId: agentId,
            completedTasks: completedTasks,
            totalEarned: totalEarned,
            reputationScore: reputationScore,
            averageRating: averageRating,
            updatedAt: block.timestamp
        });

        emit AnalyticsUpdated(agentId, completedTasks, totalEarned, reputationScore, averageRating);
    }

    function getAnalytics(bytes32 agentId) external view returns (Analytics memory) {
        return analytics[agentId];
    }

    function hasAnalytics(bytes32 agentId) external view returns (bool) {
        return analytics[agentId].updatedAt > 0;
    }
}
