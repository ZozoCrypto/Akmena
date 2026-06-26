// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentStakingEngine {
    struct Stake {
        bytes32 agentId;
        uint256 amount;
        uint256 stakedAt;
    }

    event Staked(bytes32 indexed agentId, uint256 amount);

    event Unstaked(bytes32 indexed agentId, uint256 amount);

    function stake(bytes32 agentId, uint256 amount) external;

    function unstake(bytes32 agentId, uint256 amount) external;

    function getStake(bytes32 agentId) external view returns (Stake memory);

    function stakedBalance(bytes32 agentId) external view returns (uint256);
}
