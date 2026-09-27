// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {WorkflowEngine} from "../../src/orchestration/WorkflowEngine.sol";
import {ProtocolContext} from "../../src/orchestration/IWorkflowEngine.sol";

import {AuthorizationResolver} from "../../src/authorization/AuthorizationResolver.sol";
import {CapabilityEngine} from "../../src/authorization/CapabilityEngine.sol";
import {DelegationEngine} from "../../src/authorization/DelegationEngine.sol";

import {Registry} from "../../src/registry/Registry.sol";
import {IdentityFactory} from "../../src/identity/IdentityFactory.sol";
import {Identity} from "../../src/identity/Identity.sol";
import {IIdentity} from "../../src/identity/IIdentity.sol";

import {ModuleKeys} from "../../src/libraries/ModuleKeys.sol";

contract E2ESettlement {
    event Settled(bytes32 escrowId, address actor);

    function executeSettlement(bytes32 escrowId, bytes calldata, ProtocolContext calldata ctx) external {
        emit Settled(escrowId, ctx.actor);
    }
}

contract E2EMemory {
    event Memorized(uint256 identityId, address actor);

    function commitMemory(uint256 identityId, bytes calldata, ProtocolContext calldata ctx) external {
        emit Memorized(identityId, ctx.actor);
    }
}

contract E2EReputation {
    event RepUpdated(uint256 identityId, address actor);

    function updateReputation(uint256 identityId, bytes calldata, ProtocolContext calldata ctx) external {
        emit RepUpdated(identityId, ctx.actor);
    }
}

contract AkmenaEndToEndTest is Test {
    AkmenaCore public core;
    WorkflowEngine public workflow;

    E2ESettlement public settlement;
    E2EMemory public mem;
    E2EReputation public rep;

    Registry public registry;
    Identity public implementation;
    IdentityFactory public factory;

    CapabilityEngine public capabilities;
    DelegationEngine public delegation;
    AuthorizationResolver public resolver;

    address public clientAgent = address(0x1);

    address public attacker = address(0x2);

    uint256 public identityId;
    address public identity;

    bytes32 public constant WORKFLOW_CAPABILITY = keccak256("akmena.capability.workflow");

    function setUp() public {
        core = new AkmenaCore();

        registry = new Registry();

        implementation = new Identity();

        factory = new IdentityFactory(address(implementation), address(registry));

        registry.bindIdentityFactory(address(factory));

        capabilities = new CapabilityEngine();
        delegation = new DelegationEngine();

        resolver = new AuthorizationResolver(address(registry), address(capabilities), address(delegation));

        vm.prank(clientAgent);

        identity = factory.createIdentity(IIdentity.IdentityType.Machine, "");

        identityId = registry.identityId(identity);

        vm.prank(clientAgent);

        capabilities.grantCapability(identity, WORKFLOW_CAPABILITY);

        workflow = new WorkflowEngine(address(core), address(resolver));

        settlement = new E2ESettlement();
        mem = new E2EMemory();
        rep = new E2EReputation();

        core.registerModule(ModuleKeys.WORKFLOW, address(workflow), "2.0.0");

        core.registerModule(ModuleKeys.SETTLEMENT, address(settlement), "2.0.0");

        core.registerModule(ModuleKeys.MEMORY, address(mem), "2.0.0");

        core.registerModule(ModuleKeys.REPUTATION, address(rep), "2.0.0");
    }

    function test_MasterScenario_FullLifecycle() public {
        bytes32 agreementId = keccak256("agreement.alice.bob");

        bytes32 escrowId = keccak256("escrow.alice.bob");

        vm.startPrank(clientAgent);

        bytes32 workflowId = workflow.initializeWorkflow(identityId, agreementId, escrowId);

        assertTrue(workflowId != bytes32(0), "Workflow ID generation failed");

        vm.warp(block.timestamp + 2 hours);

        vm.roll(block.number + 600);

        vm.expectEmit(false, false, false, true);

        emit E2ESettlement.Settled(escrowId, clientAgent);

        vm.expectEmit(false, false, false, true);

        emit E2EMemory.Memorized(identityId, clientAgent);

        vm.expectEmit(false, false, false, true);

        emit E2EReputation.RepUpdated(identityId, clientAgent);

        workflow.advanceToCompletion(workflowId, "", "", "");

        vm.stopPrank();
    }

    function test_AttackerCannotAdvance() public {
        bytes32 workflowId;

        vm.prank(clientAgent);

        workflowId = workflow.initializeWorkflow(identityId, keccak256("agreement.attack"), keccak256("escrow.attack"));

        vm.prank(attacker);

        vm.expectRevert(WorkflowEngine.UnauthorizedWorkflow.selector);

        workflow.advanceToCompletion(workflowId, "", "", "");
    }
}
