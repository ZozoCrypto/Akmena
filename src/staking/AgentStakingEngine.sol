// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentStakingEngine.sol";

contract AgentStakingEngine is IAgentStakingEngine {
    error ZeroAmount();
    error InsufficientStake();

    mapping(bytes32 => Stake) internal stakes;

    function stake(bytes32 agentId, uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }

        Stake storage userStake = stakes[agentId];

        userStake.agentId = agentId;
        userStake.amount += amount;

        if (userStake.stakedAt == 0) {
            userStake.stakedAt = block.timestamp;
        }

        emit Staked(agentId, amount);
    }

    function unstake(bytes32 agentId, uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }

        Stake storage userStake = stakes[agentId];

        if (userStake.amount < amount) {
            revert InsufficientStake();
        }

        userStake.amount -= amount;

        emit Unstaked(agentId, amount);
    }

    function getStake(bytes32 agentId) external view returns (Stake memory) {
        return stakes[agentId];
    }

    function stakedBalance(bytes32 agentId) external view returns (uint256) {
        return stakes[agentId].amount;
    }
}
