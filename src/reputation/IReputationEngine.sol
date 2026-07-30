// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IReputationEngine {
    event ReputationUpdated(address indexed agent, uint256 newScore);

    error InvalidAddress();

    function updateScore(address agent, uint256 score) external;
    function getScore(address agent) external view returns (uint256);
}
