// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentRatingEngine {
    struct Rating {
        bytes32 agentId;
        uint256 score;
        address reviewer;
        uint256 timestamp;
    }

    event RatingSubmitted(bytes32 indexed agentId, address indexed reviewer, uint256 score);

    function submitRating(bytes32 agentId, uint256 score) external;

    function getAverageRating(bytes32 agentId) external view returns (uint256);

    function getRatingCount(bytes32 agentId) external view returns (uint256);

    function hasRated(bytes32 agentId, address reviewer) external view returns (bool);
}
