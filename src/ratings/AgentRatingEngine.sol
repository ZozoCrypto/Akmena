// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentRatingEngine.sol";

contract AgentRatingEngine is IAgentRatingEngine {
    error InvalidScore();
    error AlreadyRated();

    mapping(bytes32 => uint256) internal totalScore;
    mapping(bytes32 => uint256) internal ratingCount;

    mapping(bytes32 => mapping(address => bool)) internal reviewerSubmitted;

    function submitRating(bytes32 agentId, uint256 score) external {
        if (score == 0 || score > 5) {
            revert InvalidScore();
        }

        if (reviewerSubmitted[agentId][msg.sender]) {
            revert AlreadyRated();
        }

        reviewerSubmitted[agentId][msg.sender] = true;

        totalScore[agentId] += score;
        ratingCount[agentId] += 1;

        emit RatingSubmitted(agentId, msg.sender, score);
    }

    function getAverageRating(bytes32 agentId) external view returns (uint256) {
        uint256 count = ratingCount[agentId];

        if (count == 0) {
            return 0;
        }

        return totalScore[agentId] / count;
    }

    function getRatingCount(bytes32 agentId) external view returns (uint256) {
        return ratingCount[agentId];
    }

    function hasRated(bytes32 agentId, address reviewer) external view returns (bool) {
        return reviewerSubmitted[agentId][reviewer];
    }
}
