// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Test} from "forge-std/Test.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {WorkflowEngine} from "../../src/orchestration/WorkflowEngine.sol";
import {ProtocolContext} from "../../src/orchestration/IWorkflowEngine.sol";

import {AuthorizationResolver} from "../../src/authorization/AuthorizationResolver.sol";
import {IAuthorizationResolver} from "../../src/authorization/IAuthorizationResolver.sol";
import {CapabilityEngine} from "../../src/authorization/CapabilityEngine.sol";
import {DelegationEngine} from "../../src/authorization/DelegationEngine.sol";

import {Registry} from "../../src/registry/Registry.sol";
import {IdentityFactory} from "../../src/identity/IdentityFactory.sol";
import {Identity} from "../../src/identity/Identity.sol";
import {IIdentity} from "../../src/identity/IIdentity.sol";

contract SecurityMockCore {
    mapping(bytes32 => address) public modules;

    function setModule(bytes32 key, address module) external {
        modules[key] = module;
    }

    function getModule(bytes32 key) external view returns (address, bool, string memory) {
        address module = modules[key];

        return (module, module != address(0), "2.0.0");
    }
}

contract CountingModule {
    uint256 public settlementCalls;
    uint256 public memoryCalls;
    uint256 public reputationCalls;

    function executeSettlement(bytes32, bytes calldata, ProtocolContext calldata) external {
        settlementCalls++;
    }

    function commitMemory(uint256, bytes calldata, ProtocolContext calldata) external {
        memoryCalls++;
    }

    function updateReputation(uint256, bytes calldata, ProtocolContext calldata) external {
        reputationCalls++;
    }
}

contract ReentrantSettlementModule {
    WorkflowEngine public immutable engine;

    bytes32 public workflowId;
    bool public reenter;
    uint256 public calls;

    constructor(WorkflowEngine engine_) {
        engine = engine_;
    }

    function configure(bytes32 workflowId_) external {
        workflowId = workflowId_;
        reenter = true;
    }

    function executeSettlement(bytes32, bytes calldata, ProtocolContext calldata) external {
        calls++;

        if (reenter) {
            reenter = false;

            engine.advanceToCompletion(workflowId, "", "", "");
        }
    }
}

contract WorkflowSecurityTest is Test {
    SecurityMockCore internal core;
    WorkflowEngine internal engine;
    CountingModule internal normalModule;

    Registry internal registry;
    Identity internal identityImplementation;
    IdentityFactory internal factory;

    CapabilityEngine internal capabilities;
    DelegationEngine internal delegation;
    AuthorizationResolver internal resolver;

    address internal owner = address(0xABCD);

    address internal delegate = address(0xDADA);

    address internal attacker = address(0xBAD);

    address internal identity;
    uint256 internal identityId;

    bytes32 internal constant WORKFLOW_CAPABILITY = keccak256("akmena.capability.workflow");

    function setUp() public {
        core = new SecurityMockCore();

        registry = new Registry();

        identityImplementation = new Identity();

        factory = new IdentityFactory(address(identityImplementation), address(registry));

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

        normalModule = new CountingModule();

        core.setModule(engine.SETTLEMENT_KEY(), address(normalModule));

        core.setModule(engine.MEMORY_KEY(), address(normalModule));

        core.setModule(engine.REPUTATION_KEY(), address(normalModule));
    }

    /// SECURITY REGRESSION:
    /// Identical inputs in the same block must produce unique workflow IDs.
    function test_WorkflowIdsAreUniqueForIdenticalSameBlockInputs() public {
        vm.startPrank(owner);

        bytes32 first = engine.initializeWorkflow(identityId, keccak256("agreement"), keccak256("escrow"));

        bytes32 second = engine.initializeWorkflow(identityId, keccak256("agreement"), keccak256("escrow"));

        vm.stopPrank();

        assertTrue(first != bytes32(0));

        assertTrue(second != bytes32(0));

        assertTrue(first != second);
    }

    /// SECURITY REGRESSION:
    /// Repeated creation must never reset or overwrite the first workflow.
    function test_RepeatedInitializationDoesNotResetExistingWorkflow() public {
        vm.startPrank(owner);

        bytes32 first = engine.initializeWorkflow(identityId, keccak256("agreement"), keccak256("escrow"));

        engine.advanceToCompletion(first, "", "", "");

        bytes32 second = engine.initializeWorkflow(identityId, keccak256("agreement"), keccak256("escrow"));

        vm.stopPrank();

        assertTrue(first != second);

        assertEq(normalModule.settlementCalls(), 1);

        assertEq(normalModule.memoryCalls(), 1);

        assertEq(normalModule.reputationCalls(), 1);

        vm.prank(owner);

        engine.advanceToCompletion(second, "", "", "");

        assertEq(normalModule.settlementCalls(), 2);

        assertEq(normalModule.memoryCalls(), 2);

        assertEq(normalModule.reputationCalls(), 2);
    }

    /// SECURITY REGRESSION:
    /// A caller without the Workflow capability must not create a workflow.
    function test_UnauthorizedCallerCannotInitializeWorkflow() public {
        vm.prank(attacker);

        vm.expectRevert(IAuthorizationResolver.Unauthorized.selector);

        engine.initializeWorkflow(identityId, keccak256("agreement.attack"), keccak256("escrow.attack"));
    }

    /// SECURITY REGRESSION:
    /// A caller without current Workflow authority cannot advance.
    function test_UnauthorizedCallerCannotAdvanceWorkflow() public {
        bytes32 workflowId;

        vm.prank(owner);

        workflowId = engine.initializeWorkflow(identityId, keccak256("agreement"), keccak256("escrow"));

        vm.prank(attacker);

        vm.expectRevert(WorkflowEngine.UnauthorizedWorkflow.selector);

        engine.advanceToCompletion(workflowId, "", "", "");
    }

    /// SECURITY REGRESSION:
    /// A properly scoped delegate may advance even though it
    /// was not the original workflow creator.
    function test_ScopedDelegateCanAdvanceWorkflow() public {
        vm.prank(owner);

        delegation.setDelegate(identity, delegate, WORKFLOW_CAPABILITY, block.timestamp + 1 days, true);

        bytes32 workflowId;

        vm.prank(owner);

        workflowId =
            engine.initializeWorkflow(identityId, keccak256("agreement.delegate"), keccak256("escrow.delegate"));

        vm.prank(delegate);

        engine.advanceToCompletion(workflowId, "", "", "");

        assertEq(normalModule.settlementCalls(), 1);

        assertEq(normalModule.memoryCalls(), 1);

        assertEq(normalModule.reputationCalls(), 1);
    }

    /// SECURITY REGRESSION:
    /// Replacing the capability must revoke Workflow authority.
    function test_RevokedWorkflowCapabilityBlocksAdvance() public {
        bytes32 workflowId;

        vm.prank(owner);

        workflowId = engine.initializeWorkflow(identityId, keccak256("agreement.revoke"), keccak256("escrow.revoke"));

        vm.prank(owner);

        capabilities.revokeCapability(identity, WORKFLOW_CAPABILITY);

        vm.prank(owner);

        vm.expectRevert(WorkflowEngine.UnauthorizedWorkflow.selector);

        engine.advanceToCompletion(workflowId, "", "", "");
    }

    /// SECURITY REGRESSION:
    /// Identity deactivation immediately removes Workflow authority.
    function test_DeactivatedIdentityBlocksAdvance() public {
        bytes32 workflowId;

        vm.prank(owner);

        workflowId =
            engine.initializeWorkflow(identityId, keccak256("agreement.inactive"), keccak256("escrow.inactive"));

        vm.prank(owner);

        Identity(identity).deactivate();

        vm.prank(owner);

        vm.expectRevert(WorkflowEngine.UnauthorizedWorkflow.selector);

        engine.advanceToCompletion(workflowId, "", "", "");
    }

    /// SECURITY REGRESSION:
    /// A malicious settlement module cannot recursively advance the
    /// same workflow because WorkflowEngine itself is non-reentrant.
    function test_ReentrantSettlementIsRejected() public {
        ReentrantSettlementModule malicious = new ReentrantSettlementModule(engine);

        core.setModule(engine.SETTLEMENT_KEY(), address(malicious));

        bytes32 workflowId;

        vm.prank(owner);

        workflowId =
            engine.initializeWorkflow(identityId, keccak256("agreement.reentrant"), keccak256("escrow.reentrant"));

        malicious.configure(workflowId);

        vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);

        vm.prank(owner);

        engine.advanceToCompletion(workflowId, "", "", "");

        assertEq(malicious.calls(), 0, "Reentrant settlement attempt must roll back atomically");
    }

    /// SECURITY REGRESSION:
    /// Invalid Core dependencies must be rejected at deployment.
    function test_RevertWhen_CoreIsZero() public {
        vm.expectRevert(WorkflowEngine.InvalidCore.selector);

        new WorkflowEngine(address(0), address(resolver));
    }

    function test_RevertWhen_CoreIsEOA() public {
        vm.expectRevert(WorkflowEngine.InvalidCore.selector);

        new WorkflowEngine(address(0xBEEF), address(resolver));
    }

    /// SECURITY REGRESSION:
    /// Invalid AuthorizationResolver dependencies must be rejected.
    function test_RevertWhen_AuthorizationResolverIsZero() public {
        vm.expectRevert(WorkflowEngine.InvalidAuthorizationResolver.selector);

        new WorkflowEngine(address(core), address(0));
    }

    function test_RevertWhen_AuthorizationResolverIsEOA() public {
        vm.expectRevert(WorkflowEngine.InvalidAuthorizationResolver.selector);

        new WorkflowEngine(address(core), address(0xBEEF));
    }

    /// SECURITY REGRESSION:
    /// Ownership rotation must immediately change Workflow authority.
    function test_OwnershipRotationChangesWorkflowAuthority() public {
        address newOwner = address(0xEEEE);

        vm.prank(owner);

        Identity(identity).transferOwnership(newOwner);

        vm.prank(owner);

        vm.expectRevert(IAuthorizationResolver.Unauthorized.selector);

        engine.initializeWorkflow(identityId, keccak256("agreement.oldowner"), keccak256("escrow.oldowner"));

        vm.prank(newOwner);

        // Capability remains attached to the Identity, and the
        // resolver uses the Identity's current owner.
        bytes32 workflowId =
            engine.initializeWorkflow(identityId, keccak256("agreement.newowner"), keccak256("escrow.newowner"));

        assertTrue(workflowId != bytes32(0));
    }
}
