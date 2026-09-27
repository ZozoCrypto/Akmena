// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {WorkflowEngine} from "../../src/orchestration/WorkflowEngine.sol";
import {IWorkflowEngine, ProtocolContext} from "../../src/orchestration/IWorkflowEngine.sol";

import {AuthorizationResolver} from "../../src/authorization/AuthorizationResolver.sol";
import {CapabilityEngine} from "../../src/authorization/CapabilityEngine.sol";
import {DelegationEngine} from "../../src/authorization/DelegationEngine.sol";

import {Identity} from "../../src/identity/Identity.sol";
import {IdentityFactory} from "../../src/identity/IdentityFactory.sol";
import {Registry} from "../../src/registry/Registry.sol";
import {IIdentity} from "../../src/identity/IIdentity.sol";

import {WorkflowHandler} from "./handlers/WorkflowHandler.sol";

contract MockCore {
    mapping(bytes32 => address) public modules;

    function setModule(bytes32 key, address addr) external {
        modules[key] = addr;
    }

    function getModule(bytes32 key) external view returns (address, bool, string memory) {
        return (modules[key], modules[key] != address(0), "v1");
    }
}

contract MockModule {
    function executeSettlement(bytes32, bytes calldata, ProtocolContext calldata) external {}

    function commitMemory(uint256, bytes calldata, ProtocolContext calldata) external {}

    function updateReputation(uint256, bytes calldata, ProtocolContext calldata) external {}
}

contract WorkflowInvariant is StdInvariant, Test {
    MockCore internal core;

    Registry internal registry;
    Identity internal implementation;
    IdentityFactory internal factory;

    CapabilityEngine internal capabilities;
    DelegationEngine internal delegation;
    AuthorizationResolver internal resolver;

    WorkflowEngine internal engine;
    WorkflowHandler internal handler;
    MockModule internal mockModule;

    address internal constant OWNER = address(0xA11CE);

    bytes32 internal constant WORKFLOW_CAPABILITY = keccak256("akmena.capability.workflow");

    function setUp() public {
        core = new MockCore();

        registry = new Registry();

        implementation = new Identity();

        factory = new IdentityFactory(address(implementation), address(registry));

        registry.bindIdentityFactory(address(factory));

        capabilities = new CapabilityEngine();
        delegation = new DelegationEngine();

        resolver = new AuthorizationResolver(address(registry), address(capabilities), address(delegation));

        vm.prank(OWNER);

        address identity = factory.createIdentity(IIdentity.IdentityType.Machine, "");

        uint256 identityId = registry.identityId(identity);

        vm.prank(OWNER);

        capabilities.grantCapability(identity, WORKFLOW_CAPABILITY);

        engine = new WorkflowEngine(address(core), address(resolver));

        handler = new WorkflowHandler(engine, identityId, OWNER);

        mockModule = new MockModule();

        core.setModule(engine.SETTLEMENT_KEY(), address(mockModule));

        core.setModule(engine.MEMORY_KEY(), address(mockModule));

        core.setModule(engine.REPUTATION_KEY(), address(mockModule));

        targetContract(address(handler));
    }

    function test_SanityCheck() public pure {
        assertTrue(true);
    }

    /// INVARIANT:
    /// Every successfully recorded workflow ID is nonzero.
    function invariant_workflowIdsAreNeverZero() public view {
        uint256 length = handler.workflowIdsLength();

        for (uint256 i = 0; i < length; ++i) {
            assertTrue(handler.workflowIds(i) != bytes32(0));
        }
    }

    /// INVARIANT:
    /// The handler's successful initialization count exactly
    /// equals its recorded workflow count.
    function invariant_initializeCountMatchesRecords() public view {
        assertEq(handler.initializeCount(), handler.workflowIdsLength());
    }

    /// SECURITY INVARIANT:
    /// No non-owner caller may successfully advance a workflow
    /// unless that caller has explicit authorization.
    ///
    /// The current invariant fixture grants workflow capability
    /// only to the canonical owner, so every non-owner success
    /// must remain zero.
    function invariant_unauthorizedAdvancesNeverSucceed() public view {
        assertEq(handler.unauthorizedAdvanceSuccesses(), 0);
    }
}
