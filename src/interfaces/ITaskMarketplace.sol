// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Akmena Task Marketplace Interface
/// @notice Canonical interface for marketplace tasks.
interface ITaskMarketplace {
    enum TaskStatus {
        Open,
        Assigned,
        Completed,
        Cancelled
    }

    struct Task {
        bytes32 id;
        bytes32 creatorAgent;
        bytes32 assignedAgent;

        uint64 createdAt;
        uint64 completedAt;

        uint256 reward;

        TaskStatus status;

        string metadataURI;
    }

    event TaskCreated(bytes32 indexed taskId, bytes32 indexed creatorAgent, uint256 reward, string metadataURI);

    event TaskAssigned(bytes32 indexed taskId, bytes32 indexed assignedAgent);

    event TaskCompleted(bytes32 indexed taskId);

    function createTask(bytes32 taskId, bytes32 creatorAgent, uint256 reward, string calldata metadataURI) external;

    function assignTask(bytes32 taskId, bytes32 assignedAgent) external;

    function completeTask(bytes32 taskId) external;

    function exists(bytes32 taskId) external view returns (bool);

    function getTask(bytes32 taskId) external view returns (Task memory);
}
