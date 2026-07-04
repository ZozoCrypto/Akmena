// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {AkmenaToken} from "../../src/token/AkmenaToken.sol";
import {AkmenaEscrow} from "../../src/escrow/AkmenaEscrow.sol";
import {IAkmenaEscrow} from "../../src/escrow/interfaces/IAkmenaEscrow.sol";
import {IArbiter} from "../../src/escrow/interfaces/IArbiter.sol";

// ═════════════════════════════════════════════════════════════════════
// Mock Master Agent (The Arbiter)
// ═════════════════════════════════════════════════════════════════════
contract MockMasterAgent is IArbiter {
    /// @notice Simulates an AI reviewing the task and triggering the release.
    function evaluateTask(address escrowAddress, bytes32 taskId, bytes calldata /* data */) external returns (bool) {
        // In a real scenario, this contract would verify a cryptographic signature 
        // from the Master Agent before executing this call.
        IAkmenaEscrow(escrowAddress).releaseFunds(taskId);
        return true;
    }
}

// ═════════════════════════════════════════════════════════════════════
// The Escrow Test Suite
// ═════════════════════════════════════════════════════════════════════
contract EscrowTest is Test {
    AkmenaToken public token;
    AkmenaEscrow public escrow;
    MockMasterAgent public arbiter;

    address public treasury = address(this);
    address public buyer = address(0x111);
    address public seller = address(0x222);

    function setUp() public {
        // 1. Deploy the Kernel
        token = new AkmenaToken(treasury);
        
        // 2. Deploy the Escrow Engine & Mock Arbiter
        escrow = new AkmenaEscrow(address(token));
        arbiter = new MockMasterAgent();

        // 3. Fund the AI Buyer
        bool success = token.transfer(buyer, 1000 * 1e18);
        assertTrue(success, "Initial funding failed");
    }

    /// @notice Proves a Buyer can lock funds and create a task in one transaction.
    function test_CreateTask_Success() public {
        bytes32 taskId = keccak256("task_001");
        uint256 deadline = block.timestamp + 1 days;
        uint256 amount = 100 * 1e18;

        // Encode the Machine-Readable SLA
        bytes memory taskData = abi.encode(taskId, seller, address(arbiter), deadline);

        // Buyer executes the atomic 1363 call
        vm.prank(buyer);
        token.transferAndCall(address(escrow), amount, taskData);

        // Assertions: Did the money lock? Did the task generate?
        assertEq(token.balanceOf(address(escrow)), amount);
        
        IAkmenaEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(task.buyer, buyer);
        assertEq(task.seller, seller);
        assertEq(task.arbiter, address(arbiter));
        assertEq(uint(task.status), uint(IAkmenaEscrow.Status.ACTIVE));
    }

    /// @notice Proves the Arbiter can release funds to the Seller.
    function test_ReleaseFunds_Success() public {
        // 1. Setup: Create the task
        test_CreateTask_Success();
        bytes32 taskId = keccak256("task_001");

        // 2. Anyone triggers the Arbiter (passing mock proof data)
        arbiter.evaluateTask(address(escrow), taskId, "");

        // Assertions: Did the Seller get paid? Is the task complete?
        assertEq(token.balanceOf(seller), 100 * 1e18);
        
        IAkmenaEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint(task.status), uint(IAkmenaEscrow.Status.COMPLETED));
    }

    /// @notice Proves the Buyer can refund if the Seller misses the deadline.
    function test_ClaimRefund_Success() public {
        // 1. Setup: Create the task
        test_CreateTask_Success();
        bytes32 taskId = keccak256("task_001");

        // 2. Simulate time passing beyond the 1-day deadline
        vm.warp(block.timestamp + 2 days);

        // 3. Buyer claims the refund
        vm.prank(buyer);
        escrow.claimRefund(taskId);

        // Assertions: Did the Buyer get their money back?
        assertEq(token.balanceOf(buyer), 1000 * 1e18); // Back to original balance
        
        IAkmenaEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint(task.status), uint(IAkmenaEscrow.Status.REFUNDED));
    }
}