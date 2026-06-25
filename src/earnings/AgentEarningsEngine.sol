// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentEarningsEngine.sol";

contract AgentEarningsEngine is IAgentEarningsEngine {
    error ZeroAmount();

    mapping(bytes32 => Earnings) internal earnings;

    function recordEarnings(bytes32 agentId, uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }

        Earnings storage record = earnings[agentId];

        record.agentId = agentId;
        record.totalEarned += amount;
        record.transactionCount += 1;
        record.lastPaymentAt = block.timestamp;

        emit EarningsRecorded(agentId, amount);
    }

    function getEarnings(bytes32 agentId) external view returns (Earnings memory) {
        return earnings[agentId];
    }

    function totalEarned(bytes32 agentId) external view returns (uint256) {
        return earnings[agentId].totalEarned;
    }

    function transactionCount(bytes32 agentId) external view returns (uint256) {
        return earnings[agentId].transactionCount;
    }
}
