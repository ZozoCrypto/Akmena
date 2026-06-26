// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentRewardEngine {
    struct Reward {
        bytes32 agentId;
        uint256 totalRewards;
        uint256 rewardEvents;
        uint256 lastRewardAt;
    }

    event RewardGranted(bytes32 indexed agentId, uint256 amount);

    function grantReward(bytes32 agentId, uint256 amount) external;

    function getRewards(bytes32 agentId) external view returns (Reward memory);

    function totalRewards(bytes32 agentId) external view returns (uint256);

    function rewardEvents(bytes32 agentId) external view returns (uint256);
}
