// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaToken} from "../src/token/AkmenaToken.sol";
import {AkmenaEscrow} from "../src/escrow/AkmenaEscrow.sol";
import {AgentRegistry} from "../src/registry/AgentRegistry.sol";
import {IAkmenaEscrow} from "../src/escrow/interfaces/IAkmenaEscrow.sol";

contract IntegrationTest is Test {
    AkmenaToken public token;
    AkmenaEscrow public escrow;
    AgentRegistry public registry;

    address public owner = address(0x1);
    address public buyer = address(0x2);
    address public seller = address(0x3);
    address public arbiter = address(0x4);

    function setUp() public {
        vm.startPrank(owner);
        token = new AkmenaToken(owner);
        escrow = new AkmenaEscrow(address(token));
        registry = new AgentRegistry();
        
        token.transfer(buyer, 1000 * 1e18);
        vm.stopPrank();
    }

    function test_SystemFlow_RegisterEscrowRelease() public {
        // 1. Identity Layer: Register the Seller Agent
        vm.prank(owner);
        registry.registerAgent(seller, "ipfs://agent-meta");
        assertTrue(registry.isAgentActive(seller));

        // 2. Financial Layer: Create Escrow Task
        bytes32 taskId = keccak256("task_001");
        uint256 duration = 1 days;
        uint256 amount = 100 * 1e18;
        bytes memory taskData = abi.encode(taskId, seller, arbiter, duration);

        vm.prank(buyer);
        token.transferAndCall(address(escrow), amount, taskData);

        // Assert escrow locked
        assertEq(token.balanceOf(address(escrow)), amount);

        // 3. Settlement Layer: Release Funds (Arbiter acts)
        vm.prank(arbiter);
        escrow.releaseFunds(taskId);

        // 4. Final Validation: Seller received payment
        assertEq(token.balanceOf(seller), amount);
        
        IAkmenaEscrow.Task memory task = escrow.getTask(taskId);
        assertEq(uint(task.status), uint(IAkmenaEscrow.Status.COMPLETED));
    }
}