// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {WorkflowEngine} from "../../src/orchestration/WorkflowEngine.sol";
import {WorkflowStep, ProtocolContext} from "../../src/orchestration/IWorkflowEngine.sol";

contract MockCore {
    mapping(bytes32 => address) public modules;
    function setModule(bytes32 key, address addr) external { modules[key] = addr; }
    function getModule(bytes32 key) external view returns (address, bool, string memory) {
        return (modules[key], true, "v1");
    }
}

// Modules independently verify the context
contract MockSettlement {
    event Settled(bytes32 escrowId, address actor);
    function executeSettlement(bytes32 escrowId, bytes calldata, ProtocolContext calldata ctx) external {
        require(ctx.actor != address(0), "Unauthorized: No actor");
        emit Settled(escrowId, ctx.actor);
    }
}
contract MockMemory {
    event Memorized(bytes32 agentId, address actor);
    function commitMemory(bytes32 agentId, bytes calldata, ProtocolContext calldata ctx) external {
        require(ctx.actor != address(0), "Unauthorized: No actor");
        emit Memorized(agentId, ctx.actor);
    }
}
contract MockReputation {
    event RepUpdated(bytes32 agentId, address actor);
    function updateReputation(bytes32 agentId, bytes calldata, ProtocolContext calldata ctx) external {
        require(ctx.actor != address(0), "Unauthorized: No actor");
        emit RepUpdated(agentId, ctx.actor);
    }
}

contract WorkflowEngineTest is Test {
    MockCore public core;
    WorkflowEngine public engine;
    MockSettlement public settlement;
    MockMemory public mem;
    MockReputation public rep;

    address public initiator = address(0xABCD);
    address public attacker = address(0xBAD);

    function setUp() public {
        core = new MockCore();
        engine = new WorkflowEngine(address(core));
        
        settlement = new MockSettlement();
        mem = new MockMemory();
        rep = new MockReputation();

        core.setModule(engine.SETTLEMENT_KEY(), address(settlement));
        core.setModule(engine.MEMORY_KEY(), address(mem));
        core.setModule(engine.REPUTATION_KEY(), address(rep));
    }

    function test_InitializeAndAdvanceWithContext() public {
        bytes32 agentId = keccak256("agent.1");
        bytes32 agreementId = keccak256("agreement.1");
        bytes32 escrowId = keccak256("escrow.1");

        vm.startPrank(initiator);
        bytes32 workflowId = engine.initializeWorkflow(agentId, agreementId, escrowId);

        // Modules should emit events proving they received the correct ProtocolContext actor
        vm.expectEmit(false, false, false, true);
        emit MockSettlement.Settled(escrowId, initiator);
        
        vm.expectEmit(false, false, false, true);
        emit MockMemory.Memorized(agentId, initiator);
        
        vm.expectEmit(false, false, false, true);
        emit MockReputation.RepUpdated(agentId, initiator);

        engine.advanceToCompletion(workflowId, "", "", "");
        vm.stopPrank();
    }

    function test_RevertWhen_AttackerCallsAdvance() public {
        bytes32 workflowId = engine.initializeWorkflow(keccak256("A"), keccak256("B"), keccak256("C"));
        
        vm.prank(attacker);
        vm.expectRevert(WorkflowEngine.UnauthorizedInitiator.selector);
        engine.advanceToCompletion(workflowId, "", "", "");
    }
}
