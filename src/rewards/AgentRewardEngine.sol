// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentRewardEngine.sol";

contract AgentRewardEngine is IAgentRewardEngine {
    error ZeroAmount();

    mapping(bytes32 => Reward) internal rewards;

    function grantReward(bytes32 agentId, uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }

        Reward storage reward = rewards[agentId];

        reward.agentId = agentId;
        reward.totalRewards += amount;
        reward.rewardEvents += 1;
        reward.lastRewardAt = block.timestamp;

        emit RewardGranted(agentId, amount);
    }

    function getRewards(bytes32 agentId) external view returns (Reward memory) {
        return rewards[agentId];
    }

    function totalRewards(bytes32 agentId) external view returns (uint256) {
        return rewards[agentId].totalRewards;
    }

    function rewardEvents(bytes32 agentId) external view returns (uint256) {
        return rewards[agentId].rewardEvents;
    }
}
