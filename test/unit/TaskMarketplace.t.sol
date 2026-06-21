// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/marketplace/TaskMarketplace.sol";

contract TaskMarketplaceTest is Test {
    TaskMarketplace marketplace;

    bytes32 internal constant TASK_ID = keccak256("task-1");

    bytes32 internal constant CREATOR_AGENT = keccak256("creator");

    bytes32 internal constant WORKER_AGENT = keccak256("worker");

    string internal constant METADATA_URI = "ipfs://task";

    uint256 internal constant REWARD = 1000;

    function setUp() public {
        marketplace = new TaskMarketplace();
    }

    function testCreateTask() public {
        marketplace.createTask(TASK_ID, CREATOR_AGENT, REWARD, METADATA_URI);

        assertTrue(marketplace.exists(TASK_ID));
    }

    function testCannotCreateDuplicateTask() public {
        marketplace.createTask(TASK_ID, CREATOR_AGENT, REWARD, METADATA_URI);

        vm.expectRevert(TaskMarketplace.TaskAlreadyExists.selector);

        marketplace.createTask(TASK_ID, CREATOR_AGENT, REWARD, METADATA_URI);
    }

    function testTaskStoredCorrectly() public {
        marketplace.createTask(TASK_ID, CREATOR_AGENT, REWARD, METADATA_URI);

        ITaskMarketplace.Task memory task = marketplace.getTask(TASK_ID);

        assertEq(task.creatorAgent, CREATOR_AGENT);

        assertEq(task.reward, REWARD);

        assertEq(task.metadataURI, METADATA_URI);
    }

    function testTaskStartsOpen() public {
        marketplace.createTask(TASK_ID, CREATOR_AGENT, REWARD, METADATA_URI);

        ITaskMarketplace.Task memory task = marketplace.getTask(TASK_ID);

        assertEq(uint256(task.status), uint256(ITaskMarketplace.TaskStatus.Open));
    }

    function testAssignTask() public {
        marketplace.createTask(TASK_ID, CREATOR_AGENT, REWARD, METADATA_URI);

        marketplace.assignTask(TASK_ID, WORKER_AGENT);

        ITaskMarketplace.Task memory task = marketplace.getTask(TASK_ID);

        assertEq(task.assignedAgent, WORKER_AGENT);
    }

    function testCompleteTask() public {
        marketplace.createTask(TASK_ID, CREATOR_AGENT, REWARD, METADATA_URI);

        marketplace.assignTask(TASK_ID, WORKER_AGENT);

        marketplace.completeTask(TASK_ID);

        ITaskMarketplace.Task memory task = marketplace.getTask(TASK_ID);

        assertEq(uint256(task.status), uint256(ITaskMarketplace.TaskStatus.Completed));
    }

    function testCannotCompleteBeforeAssign() public {
        marketplace.createTask(TASK_ID, CREATOR_AGENT, REWARD, METADATA_URI);

        vm.expectRevert(TaskMarketplace.InvalidStatusTransition.selector);

        marketplace.completeTask(TASK_ID);
    }

    function testUnknownTaskReverts() public {
        vm.expectRevert(TaskMarketplace.TaskNotFound.selector);

        marketplace.getTask(TASK_ID);
    }
}
