// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {WorkflowEngine} from "../../src/orchestration/WorkflowEngine.sol";
import {ProtocolContext} from "../../src/orchestration/IWorkflowEngine.sol";
import {WorkflowHandler} from "./handlers/WorkflowHandler.sol";

contract MockCore {
    mapping(bytes32 => address) public modules;
    function setModule(bytes32 key, address addr) external { modules[key] = addr; }
    function getModule(bytes32 key) external view returns (address, bool, string memory) {
        return (modules[key], true, "v1");
    }
}

contract MockModule {
    function executeSettlement(bytes32, bytes calldata, ProtocolContext calldata) external {}
    function commitMemory(bytes32, bytes calldata, ProtocolContext calldata) external {}
    function updateReputation(bytes32, bytes calldata, ProtocolContext calldata) external {}
}

contract WorkflowInvariant is StdInvariant, Test {
    MockCore internal core;
    WorkflowEngine internal engine;
    WorkflowHandler internal handler;
    MockModule internal mockModule;

    function setUp() public {
        core = new MockCore();
        engine = new WorkflowEngine(address(core));
        handler = new WorkflowHandler(engine);
        mockModule = new MockModule();

        core.setModule(engine.SETTLEMENT_KEY(), address(mockModule));
        core.setModule(engine.MEMORY_KEY(), address(mockModule));
        core.setModule(engine.REPUTATION_KEY(), address(mockModule));

        targetContract(address(handler));
    }

    function test_SanityCheck() public pure {
        assertTrue(true);
    }

    /// INVARIANT: Initialization count strictly matches recorded workflow IDs
    function invariant_initializeCountMatchesRecords() public view {
        assertEq(handler.initializeCount(), handler.workflowIdsLength());
    }

    /// SECURITY INVARIANT: Unauthorized actors can NEVER advance workflows
    function invariant_onlyInitiatorCanAdvance() public view {
        assertEq(handler.unauthorizedAdvanceSuccesses(), 0);
    }

    /// INVARIANT: Workflow IDs generated must never be zero
    function invariant_workflowIdsAreNeverZero() public view {
        uint256 length = handler.workflowIdsLength();
        for (uint256 i = 0; i < length; ++i) {
            bytes32 id = handler.workflowIds(i);
            assertTrue(id != bytes32(0));
        }
    }
}
