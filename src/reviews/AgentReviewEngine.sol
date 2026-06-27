// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentReviewEngine.sol";

contract AgentReviewEngine is IAgentReviewEngine {
    error EmptyReviewer();
    error EmptyComment();

    mapping(bytes32 => Review[]) internal reviews;

    function submitReview(bytes32 agentId, string calldata reviewer, string calldata comment) external {
        if (bytes(reviewer).length == 0) {
            revert EmptyReviewer();
        }

        if (bytes(comment).length == 0) {
            revert EmptyComment();
        }

        reviews[agentId].push(
            Review({agentId: agentId, reviewer: reviewer, comment: comment, createdAt: block.timestamp})
        );

        emit ReviewSubmitted(agentId, reviewer, comment);
    }

    function getReviews(bytes32 agentId) external view returns (Review[] memory) {
        return reviews[agentId];
    }

    function reviewCount(bytes32 agentId) external view returns (uint256) {
        return reviews[agentId].length;
    }
}
