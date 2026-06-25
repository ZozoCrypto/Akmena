// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentEarningsEngine {
    struct Earnings {
        bytes32 agentId;
        uint256 totalEarned;
        uint256 transactionCount;
        uint256 lastPaymentAt;
    }

    event EarningsRecorded(bytes32 indexed agentId, uint256 amount);

    function recordEarnings(bytes32 agentId, uint256 amount) external;

    function getEarnings(bytes32 agentId) external view returns (Earnings memory);

    function totalEarned(bytes32 agentId) external view returns (uint256);

    function transactionCount(bytes32 agentId) external view returns (uint256);
}
