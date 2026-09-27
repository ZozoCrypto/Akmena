// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {WorkflowEngine} from "../../src/orchestration/WorkflowEngine.sol";
import {WorkflowStep, ProtocolContext} from "../../src/orchestration/IWorkflowEngine.sol";

import {AuthorizationResolver} from "../../src/authorization/AuthorizationResolver.sol";
import {CapabilityEngine} from "../../src/authorization/CapabilityEngine.sol";
import {DelegationEngine} from "../../src/authorization/DelegationEngine.sol";

import {Registry} from "../../src/registry/Registry.sol";
import {IdentityFactory} from "../../src/identity/IdentityFactory.sol";
import {Identity} from "../../src/identity/Identity.sol";
import {IIdentity} from "../../src/identity/IIdentity.sol";

contract MockCore {
    mapping(bytes32 => address) public modules;

    function setModule(bytes32 key, address addr) external {
        modules[key] = addr;
    }

    function getModule(bytes32 key) external view returns (address, bool, string memory) {
        return (modules[key], modules[key] != address(0), "v1");
    }
}

contract MockSettlement {
    event Settled(bytes32 escrowId, address actor);

    function executeSettlement(bytes32 escrowId, bytes calldata, ProtocolContext calldata ctx) external {
        require(ctx.actor != address(0), "Unauthorized: No actor");

        emit Settled(escrowId, ctx.actor);
    }
}

contract MockMemory {
    event Memorized(uint256 identityId, address actor);

    function commitMemory(uint256 identityId, bytes calldata, ProtocolContext calldata ctx) external {
        require(ctx.actor != address(0), "Unauthorized: No actor");

        emit Memorized(identityId, ctx.actor);
    }
}

contract MockReputation {
    event RepUpdated(uint256 identityId, address actor);

    function updateReputation(uint256 identityId, bytes calldata, ProtocolContext calldata ctx) external {
        require(ctx.actor != address(0), "Unauthorized: No actor");

        emit RepUpdated(identityId, ctx.actor);
    }
}

contract WorkflowEngineTest is Test {
    MockCore public core;
    WorkflowEngine public engine;

    MockSettlement public settlement;
    MockMemory public mem;
    MockReputation public rep;

    Registry public registry;
    Identity public implementation;
    IdentityFactory public factory;

    CapabilityEngine public capabilities;
    DelegationEngine public delegation;
    AuthorizationResolver public resolver;

    address public owner = address(0xABCD);

    address public delegate = address(0xDADA);

    address public attacker = address(0xBAD);

    uint256 public identityId;
    address public identity;

    bytes32 public constant WORKFLOW_CAPABILITY = keccak256("akmena.capability.workflow");

    function setUp() public {
        core = new MockCore();

        registry = new Registry();

        implementation = new Identity();

        factory = new IdentityFactory(address(implementation), address(registry));

        registry.bindIdentityFactory(address(factory));

        capabilities = new CapabilityEngine();
        delegation = new DelegationEngine();

        resolver = new AuthorizationResolver(address(registry), address(capabilities), address(delegation));

        vm.prank(owner);

        identity = factory.createIdentity(IIdentity.IdentityType.Machine, "");

        identityId = registry.identityId(identity);

        vm.prank(owner);

        capabilities.grantCapability(identity, WORKFLOW_CAPABILITY);

        engine = new WorkflowEngine(address(core), address(resolver));

        settlement = new MockSettlement();
        mem = new MockMemory();
        rep = new MockReputation();

        core.setModule(engine.SETTLEMENT_KEY(), address(settlement));

        core.setModule(engine.MEMORY_KEY(), address(mem));

        core.setModule(engine.REPUTATION_KEY(), address(rep));
    }

    function test_InitializeAndAdvanceWithContext() public {
        bytes32 agreementId = keccak256("agreement.1");

        bytes32 escrowId = keccak256("escrow.1");

        vm.startPrank(owner);

        bytes32 workflowId = engine.initializeWorkflow(identityId, agreementId, escrowId);

        vm.expectEmit(false, false, false, true);

        emit MockSettlement.Settled(escrowId, owner);

        vm.expectEmit(false, false, false, true);

        emit MockMemory.Memorized(identityId, owner);

        vm.expectEmit(false, false, false, true);

        emit MockReputation.RepUpdated(identityId, owner);

        engine.advanceToCompletion(workflowId, "", "", "");

        vm.stopPrank();
    }

    function test_RevertWhen_AttackerCallsAdvance() public {
        bytes32 workflowId;

        vm.prank(owner);

        workflowId = engine.initializeWorkflow(identityId, keccak256("A"), keccak256("C"));

        vm.prank(attacker);

        vm.expectRevert(WorkflowEngine.UnauthorizedWorkflow.selector);

        engine.advanceToCompletion(workflowId, "", "", "");
    }

    function test_DelegateCanAdvanceWhenScoped() public {
        vm.prank(owner);

        delegation.setDelegate(identity, delegate, WORKFLOW_CAPABILITY, block.timestamp + 1 days, true);

        bytes32 workflowId;

        vm.prank(owner);

        workflowId =
            engine.initializeWorkflow(identityId, keccak256("delegated.agreement"), keccak256("delegated.escrow"));

        vm.prank(delegate);

        engine.advanceToCompletion(workflowId, "", "", "");
    }
}
