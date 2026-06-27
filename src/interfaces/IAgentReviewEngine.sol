// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentReviewEngine {
    struct Review {
        bytes32 agentId;
        string reviewer;
        string comment;
        uint256 createdAt;
    }

    event ReviewSubmitted(bytes32 indexed agentId, string reviewer, string comment);

    function submitReview(bytes32 agentId, string calldata reviewer, string calldata comment) external;

    function getReviews(bytes32 agentId) external view returns (Review[] memory);

    function reviewCount(bytes32 agentId) external view returns (uint256);
}
