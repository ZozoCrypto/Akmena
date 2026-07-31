// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {WorkflowEngine} from "../../src/orchestration/WorkflowEngine.sol";
import {IWorkflowEngine, ProtocolContext, WorkflowStep} from "../../src/orchestration/IWorkflowEngine.sol";
import {ModuleKeys} from "../../src/libraries/ModuleKeys.sol";

// We use lightweight mocks for the underlying engines in the E2E Router test 
// to prove the WorkflowEngine correctly routes the ProtocolContext across the stack.
// In a full staging environment, these point to the live deployed engines.

contract E2ESettlement {
    event Settled(bytes32 escrowId, address actor);
    function executeSettlement(bytes32 escrowId, bytes calldata, ProtocolContext calldata ctx) external {
        emit Settled(escrowId, ctx.actor);
    }
}

contract E2EMemory {
    event Memorized(bytes32 agentId, address actor);
    function commitMemory(bytes32 agentId, bytes calldata, ProtocolContext calldata ctx) external {
        emit Memorized(agentId, ctx.actor);
    }
}

contract E2EReputation {
    event RepUpdated(bytes32 agentId, address actor);
    function updateReputation(bytes32 agentId, bytes calldata, ProtocolContext calldata ctx) external {
        emit RepUpdated(agentId, ctx.actor);
    }
}

contract AkmenaEndToEndTest is Test {
    AkmenaCore public core;
    WorkflowEngine public workflow;
    
    E2ESettlement public settlement;
    E2EMemory public mem;
    E2EReputation public rep;

    // FIXED: Using valid hex formatting
    address public clientAgent = address(0x1);
    address public providerAgent = address(0x2);

    function setUp() public {
        core = new AkmenaCore();
        workflow = new WorkflowEngine(address(core));
        settlement = new E2ESettlement();
        mem = new E2EMemory();
        rep = new E2EReputation();

        core.registerModule(ModuleKeys.WORKFLOW, address(workflow), "2.0.0");
        core.registerModule(ModuleKeys.SETTLEMENT, address(settlement), "2.0.0");
        core.registerModule(ModuleKeys.MEMORY, address(mem), "2.0.0");
        core.registerModule(ModuleKeys.REPUTATION, address(rep), "2.0.0");
    }

    function test_MasterScenario_FullLifecycle() public {
        bytes32 agentId = keccak256("identity.bob");
        bytes32 agreementId = keccak256("agreement.alice.bob");
        bytes32 escrowId = keccak256("escrow.alice.bob");

        vm.startPrank(clientAgent);
        
        bytes32 workflowId = workflow.initializeWorkflow(agentId, agreementId, escrowId);
        assertTrue(workflowId != bytes32(0), "Workflow ID generation failed");

        vm.warp(block.timestamp + 2 hours);
        vm.roll(block.number + 600);
        
        vm.expectEmit(false, false, false, true);
        emit E2ESettlement.Settled(escrowId, clientAgent);
        
        vm.expectEmit(false, false, false, true);
        emit E2EMemory.Memorized(agentId, clientAgent);
        
        vm.expectEmit(false, false, false, true);
        emit E2EReputation.RepUpdated(agentId, clientAgent);

        workflow.advanceToCompletion(workflowId, "", "", "");
        
        vm.stopPrank();
    }
}
