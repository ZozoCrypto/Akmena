// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";
import {WorkflowEngine} from "../../../src/orchestration/WorkflowEngine.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract MockTarget {
    function ping() external pure returns (bool) { return true; }
}

contract MockCrossModule {
    function getBalance() external pure returns (uint256) { return 0; }
}

contract Attack_EconomicEscalationTest is Test {
    AkmenaCore core;
    EscrowEngine escrow;
    WorkflowEngine workflow;
    AkmenaPolicyBoundary policyBoundary;
    MockTarget target;
    MockCrossModule maliciousEscrow;

    address internal operator = address(0xBEEF);
    address internal agent = address(0x9999);
    address internal seller = address(0xCAFE);

    function setUp() public {
        core = new AkmenaCore();
        escrow = new EscrowEngine();
        policyBoundary = new AkmenaPolicyBoundary(address(core));
        workflow = new WorkflowEngine(address(core));
        target = new MockTarget();
        maliciousEscrow = new MockCrossModule();

        core.registerModule(bytes32("ESCROW_ENGINE"), address(escrow), "1.0.0");
        core.registerModule(bytes32("WORKFLOW_ENGINE"), address(workflow), "1.0.0");
        core.registerModule(bytes32("POLICY_BOUNDARY"), address(policyBoundary), "1.0.0");
        core.registerModule(bytes32("TREASURY_ENGINE"), address(maliciousEscrow), "1.0.0");
    }

    function test_Attack_PolicyBypassViaPhantomEscrow() public {
        vm.prank(operator);
        policyBoundary.setAgentPolicy(agent, 1e24, 1e24, true);

        // Operator creates a real escrow, but does NOT fund it with a transient proof
        vm.prank(operator);
        uint256 fakeEscrowId = escrow.createEscrow(operator, seller, 100 ether);

        bytes memory payload = abi.encodeWithSignature("ping()");

        // The attack: Agent tries to execute using the unfunded escrow ID
        vm.prank(agent);
        
        // Fix: We now strictly expect the boundary to throw its custom InvalidTransientProof error
        vm.expectRevert(AkmenaPolicyBoundary.InvalidTransientProof.selector);
        
        // Fix: Call using the 6-argument signature with the ESCROW_ENGINE key
        policyBoundary.executeAgentCall(
            operator,
            address(target),
            10 ether,
            bytes32("ESCROW_ENGINE"),
            fakeEscrowId,
            payload
        );
    }
}
