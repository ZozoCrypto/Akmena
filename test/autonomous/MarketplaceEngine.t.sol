// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MarketplaceEngine} from "../../src/autonomous/MarketplaceEngine.sol";
import {IMarketplaceEngine} from "../../src/autonomous/IMarketplaceEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";

contract MarketplaceEngineTest is Test {
    MarketplaceEngine public engine;
    address public creator = address(0x111);
    address public assignee = address(0x222);

    function setUp() public {
        engine = new MarketplaceEngine();
    }

    function test_CreateTask() public {
        vm.prank(creator);
        vm.expectEmit(true, true, true, true);
        emit IMarketplaceEngine.TaskCreated(1, creator, 1000);

        uint256 id = engine.createTask(1000);
        assertEq(id, 1);
        
        LibStorage.TaskData memory data = engine.getTask(id);
        assertEq(data.creator, creator);
        assertEq(data.status, 1); // Open
        assertEq(data.reward, 1000);
    }

    function test_AssignTask() public {
        vm.startPrank(creator);
        uint256 id = engine.createTask(1000);

        vm.expectEmit(true, true, true, true);
        emit IMarketplaceEngine.TaskAssigned(id, assignee);

        engine.assignTask(id, assignee);
        vm.stopPrank();

        LibStorage.TaskData memory data = engine.getTask(id);
        assertEq(data.assignee, assignee);
        assertEq(data.status, 2); // Assigned
    }

    function test_CompleteTask() public {
        vm.startPrank(creator);
        uint256 id = engine.createTask(1000);
        engine.assignTask(id, assignee);
        vm.stopPrank();

        vm.prank(assignee);
        vm.expectEmit(true, true, true, true);
        emit IMarketplaceEngine.TaskCompleted(id);

        engine.completeTask(id, assignee);
        
        LibStorage.TaskData memory data = engine.getTask(id);
        assertEq(data.status, 3); // Completed
    }

    function test_RevertWhen_AssigningUnopenTask() public {
        vm.startPrank(creator);
        uint256 id = engine.createTask(1000);
        engine.assignTask(id, assignee); // Task is now Assigned

        vm.expectRevert(IMarketplaceEngine.TaskNotOpen.selector);
        engine.assignTask(id, address(0x333));
        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedComplete() public {
        vm.startPrank(creator);
        uint256 id = engine.createTask(1000);
        engine.assignTask(id, assignee);
        vm.stopPrank();

        vm.prank(address(0x999)); // Random address
        vm.expectRevert(IMarketplaceEngine.UnauthorizedAccess.selector);
        engine.completeTask(id, address(0x999));
    }
}
