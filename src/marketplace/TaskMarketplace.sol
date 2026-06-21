// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/ITaskMarketplace.sol";

/// @title Akmena Task Marketplace
/// @notice Marketplace for agent tasks.
contract TaskMarketplace is ITaskMarketplace {
    error TaskAlreadyExists();
    error TaskNotFound();
    error InvalidMetadata();
    error InvalidReward();
    error InvalidStatusTransition();

    mapping(bytes32 => Task) internal tasks;

    function createTask(bytes32 taskId, bytes32 creatorAgent, uint256 reward, string calldata metadataURI) external {
        if (exists(taskId)) {
            revert TaskAlreadyExists();
        }

        if (reward == 0) {
            revert InvalidReward();
        }

        if (bytes(metadataURI).length == 0) {
            revert InvalidMetadata();
        }

        tasks[taskId] = Task({
            id: taskId,
            creatorAgent: creatorAgent,
            assignedAgent: bytes32(0),
            createdAt: uint64(block.timestamp),
            completedAt: 0,
            reward: reward,
            status: TaskStatus.Open,
            metadataURI: metadataURI
        });

        emit TaskCreated(taskId, creatorAgent, reward, metadataURI);
    }

    function assignTask(bytes32 taskId, bytes32 assignedAgent) external {
        if (!exists(taskId)) {
            revert TaskNotFound();
        }

        Task storage task = tasks[taskId];

        if (task.status != TaskStatus.Open) {
            revert InvalidStatusTransition();
        }

        task.assignedAgent = assignedAgent;
        task.status = TaskStatus.Assigned;

        emit TaskAssigned(taskId, assignedAgent);
    }

    function completeTask(bytes32 taskId) external {
        if (!exists(taskId)) {
            revert TaskNotFound();
        }

        Task storage task = tasks[taskId];

        if (task.status != TaskStatus.Assigned) {
            revert InvalidStatusTransition();
        }

        task.status = TaskStatus.Completed;
        task.completedAt = uint64(block.timestamp);

        emit TaskCompleted(taskId);
    }

    function exists(bytes32 taskId) public view returns (bool) {
        return tasks[taskId].createdAt != 0;
    }

    function getTask(bytes32 taskId) external view returns (Task memory) {
        if (!exists(taskId)) {
            revert TaskNotFound();
        }

        return tasks[taskId];
    }
}
