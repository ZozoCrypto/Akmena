// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibStorage} from "../storage/LibStorage.sol";

interface IMarketplaceEngine {
    event TaskCreated(uint256 indexed taskId, address indexed creator, uint256 reward);
    event TaskAssigned(uint256 indexed taskId, address indexed assignee);
    event TaskCompleted(uint256 indexed taskId);

    error InvalidAddress();
    error TaskNotFound();
    error TaskNotOpen();
    error TaskNotAssigned();
    error UnauthorizedAccess();

    function createTask(uint256 reward) external returns (uint256);
    function assignTask(uint256 taskId, address assignee) external;
    function completeTask(uint256 taskId, address caller) external;
    function getTask(uint256 taskId) external view returns (LibStorage.TaskData memory);
}
