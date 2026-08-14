// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

// Target contract that tracks successful execution
contract StatefulTarget {
    uint256 public executionCount;

    function performAction() external {
        executionCount++;
    }
}

contract Attack_CalldataSuffixTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    StatefulTarget internal target;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        target = new StatefulTarget();

        vm.prank(operator);
        boundary.setAgentPolicy(agent, 100 ether, 100 ether, false);
    }

    // =========================================================================
    // PHASE I: BASE ACCOUNT ABSTRACTION (ERC-8021 ATTACKS)
    // =========================================================================

    function test_Attack_ERC8021DataSuffixInjection() public {
        // STEP 1: Construct the valid payload the AI wants to execute
        bytes memory payload = abi.encodeWithSelector(StatefulTarget.performAction.selector);

        // STEP 2: Construct the standard top-level call to the Policy Boundary
        bytes memory standardCall = abi.encodeWithSelector(
            AkmenaPolicyBoundary.executeAgentCall.selector, operator, address(target), 10 ether, 0, payload
        );

        // STEP 3: EXPLOIT ATTEMPT - Append a malicious/attribution suffix
        // mimicking an ERC-4337 Smart Wallet on Base (ERC-8021 compliant).
        bytes32 maliciousSuffix = bytes32(0xDEADBEEF00000000000000000000000000000000000000000000000000000000);
        bytes memory appendedCall = abi.encodePacked(standardCall, maliciousSuffix);

        // STEP 4: Agent executes the raw, suffixed transaction
        vm.startPrank(agent);
        (bool success,) = address(boundary).call(appendedCall);
        vm.stopPrank();

        // VERIFY STATE
        assertTrue(success, "CRITICAL: Akmena reverted due to ERC-8021 data suffix (Smart Wallet DoS)!");
        assertEq(target.executionCount(), 1, "CRITICAL: Payload execution failed due to calldata offset corruption!");

        // Verify budget was correctly consumed despite the suffix
        (,, uint256 spentToday,,) = boundary.agentPolicies(operator, agent);
        assertEq(spentToday, 10 ether, "CRITICAL: Policy budget accounting bypassed by suffix!");
    }
}
