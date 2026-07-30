// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMarketplaceEngine} from "./IMarketplaceEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract MarketplaceEngine is IMarketplaceEngine {
    function createTask(uint256 reward) external override returns (uint256) {
        LibStorage.MarketplaceStorage storage ds = LibStorage.marketplace();
        
        if (ds.nextTaskId == 0) ds.nextTaskId = 1;
        uint256 currentId = ds.nextTaskId;
        
        ds.tasks[currentId] = LibStorage.TaskData({
            creator: msg.sender,
            assignee: address(0),
            reward: reward,
            status: 1 // 1 = Open
        });

        ds.nextTaskId++;
        emit TaskCreated(currentId, msg.sender, reward);
        
        return currentId;
    }

    function assignTask(uint256 taskId, address assignee) external override {
        if (assignee == address(0)) revert InvalidAddress();
        
        LibStorage.MarketplaceStorage storage ds = LibStorage.marketplace();
        LibStorage.TaskData storage taskData = ds.tasks[taskId];

        if (taskData.creator == address(0)) revert TaskNotFound();
        if (taskData.status != 1) revert TaskNotOpen();
        if (msg.sender != taskData.creator) revert UnauthorizedAccess();

        taskData.assignee = assignee;
        taskData.status = 2; // 2 = Assigned

        emit TaskAssigned(taskId, assignee);
    }

    function completeTask(uint256 taskId, address caller) external override {
        LibStorage.MarketplaceStorage storage ds = LibStorage.marketplace();
        LibStorage.TaskData storage taskData = ds.tasks[taskId];

        if (taskData.creator == address(0)) revert TaskNotFound();
        if (taskData.status != 2) revert TaskNotAssigned();
        if (caller != taskData.creator && caller != taskData.assignee) revert UnauthorizedAccess();

        taskData.status = 3; // 3 = Completed

        emit TaskCompleted(taskId);
    }

    function getTask(uint256 taskId) external view override returns (LibStorage.TaskData memory) {
        return LibStorage.marketplace().tasks[taskId];
    }
}
