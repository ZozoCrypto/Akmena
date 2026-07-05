// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaEscrow} from "../../src/escrow/AkmenaEscrow.sol";
import {IAkmenaEscrow} from "../../src/escrow/interfaces/IAkmenaEscrow.sol";
import {EscrowErrors} from "../../src/escrow/lib/EscrowErrors.sol";

// Minimal mock to satisfy the Escrow interface
contract MockToken {
    function transfer(address to, uint256 amount) external returns (bool) { return true; }
}

contract EscrowUnitTest is Test {
    AkmenaEscrow public escrow;
    MockToken public mockToken;

    address public buyer = address(0x1);
    address public seller = address(0x2);
    address public arbiter = address(0x3);

    function setUp() public {
        mockToken = new MockToken();
        escrow = new AkmenaEscrow(address(mockToken));
    }

    // --- Creation Tests ---

    function test_CreateTask_Success() public {
        bytes32 taskId = bytes32("task1");
        uint256 duration = 1 days;
        bytes memory data = abi.encode(taskId, seller, arbiter, duration);

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit IAkmenaEscrow.TaskCreated(taskId, buyer, seller, 100);

        vm.prank(address(mockToken));
        escrow.onTransferReceived(address(0), buyer, 100, data);

        IAkmenaEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint256(task.status), uint256(IAkmenaEscrow.Status.ACTIVE));
        assertEq(task.duration, duration);
    }

    function test_CreateTask_Revert_InvalidDuration() public {
        bytes32 taskId = bytes32("task2");
        bytes memory data = abi.encode(taskId, seller, arbiter, 45 days); // Too long

        vm.prank(address(mockToken));
        vm.expectRevert(EscrowErrors.InvalidTaskData.selector);
        escrow.onTransferReceived(address(0), buyer, 100, data);
    }

    // --- Resolution Tests ---

    function test_ReleaseFunds_Success() public {
        bytes32 taskId = bytes32("task3");
        bytes memory data = abi.encode(taskId, seller, arbiter, 1 days);
        
        vm.prank(address(mockToken));
        escrow.onTransferReceived(address(0), buyer, 100, data);

        vm.prank(arbiter);
        escrow.releaseFunds(taskId);

        IAkmenaEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint256(task.status), uint256(IAkmenaEscrow.Status.COMPLETED));
    }

    // --- Refund Tests ---

    function test_ClaimRefund_Revert_TooEarly() public {
        bytes32 taskId = bytes32("task4");
        bytes memory data = abi.encode(taskId, seller, arbiter, 1 days);
        
        vm.prank(address(mockToken));
        escrow.onTransferReceived(address(0), buyer, 100, data);

        // Try to claim immediately (should fail)
        vm.prank(buyer);
        vm.expectRevert(EscrowErrors.DeadlineNotPassed.selector);
        escrow.claimRefund(taskId);
    }

    function test_ClaimRefund_Success_AfterGracePeriod() public {
        bytes32 taskId = bytes32("task5");
        uint256 duration = 1 days;
        bytes memory data = abi.encode(taskId, seller, arbiter, duration);
        
        vm.prank(address(mockToken));
        escrow.onTransferReceived(address(0), buyer, 100, data);

        // Warp time forward past duration + grace period
        vm.warp(block.timestamp + duration + 5 minutes + 1);

        vm.prank(buyer);
        escrow.claimRefund(taskId);

        IAkmenaEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint256(task.status), uint256(IAkmenaEscrow.Status.REFUNDED));
    }
}