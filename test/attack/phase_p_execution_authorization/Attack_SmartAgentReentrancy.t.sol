// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract SmartAgentReentrancyTarget {
    AkmenaPolicyBoundary public immutable boundary;

    AkmenaExecutionAuthorization.ExecutionIntent public nestedIntent;
    bytes public nestedPayload;
    bytes public nestedSignature;

    bool public attemptReentry;
    bool public reentrySucceeded;
    uint256 public reentryCount;

    constructor(AkmenaPolicyBoundary boundary_) {
        boundary = boundary_;
    }

    function configureReentry(
        AkmenaExecutionAuthorization.ExecutionIntent calldata intent,
        bytes calldata payload,
        bytes calldata signature
    ) external {
        nestedIntent = intent;
        nestedPayload = payload;
        nestedSignature = signature;
        attemptReentry = true;
        reentrySucceeded = false;
        reentryCount = 0;
    }

    function clearReentry() external {
        attemptReentry = false;
    }

    function execute() external {
        if (!attemptReentry || reentryCount != 0) {
            return;
        }

        reentryCount++;

        try boundary.executeAuthorizedAgentCall(nestedIntent, nestedPayload, nestedSignature) {
            reentrySucceeded = true;
        } catch {
            reentrySucceeded = false;
        }
    }

    // ERC-1271
    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
        return this.isValidSignature.selector;
    }
}

contract AttackSmartAgentReentrancyTest is Test {
    address internal operator = address(0x1111);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    SmartAgentReentrancyTarget internal agent;

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));

        // The smart-contract agent is also the execution target.
        // This is essential: the reentrant call must arrive with
        // msg.sender == intent.agent.
        agent = new SmartAgentReentrancyTarget(boundary);

        vm.prank(operator);
        boundary.setAgentPolicy(
            address(agent),
            20 ether, // max per transaction
            20 ether, // daily limit
            false
        );
    }

    function _intent(uint256 amount, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        bytes memory payload = abi.encodeWithSelector(SmartAgentReentrancyTarget.execute.selector);

        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: address(agent),
            target: address(agent),
            selector: SmartAgentReentrancyTarget.execute.selector,
            calldataHash: keccak256(payload),
            asset: address(0),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal pure returns (bytes memory) {
        // The test agent accepts ERC-1271 signatures, so the bytes
        // themselves are intentionally irrelevant to this harness.
        intent;
        return hex"1234";
    }

    function test_RedTeam_SmartAgentReentrancyCannotBypassDailyLimit() public {
        uint256 amount = 12 ether;

        // Nested execution: 12 ETH
        AkmenaExecutionAuthorization.ExecutionIntent memory nested = _intent(amount, 1);

        bytes memory nestedPayload = abi.encodeWithSelector(SmartAgentReentrancyTarget.execute.selector);

        bytes memory nestedSignature = _sign(nested);

        agent.configureReentry(nested, nestedPayload, nestedSignature);

        // Outer execution: another 12 ETH
        // Daily limit is only 20 ETH.
        AkmenaExecutionAuthorization.ExecutionIntent memory outer = _intent(amount, 0);

        bytes memory outerPayload = abi.encodeWithSelector(SmartAgentReentrancyTarget.execute.selector);

        bytes memory outerSignature = _sign(outer);

        vm.prank(address(agent));

        boundary.executeAuthorizedAgentCall(outer, outerPayload, outerSignature);

        assertEq(agent.reentryCount(), 1, "smart-agent reentry did not occur");

        assertFalse(agent.reentrySucceeded(), "smart-agent reentry unexpectedly succeeded");

        (,, uint256 spentToday,,) = boundary.agentPolicies(operator, address(agent));

        // The nested execution is blocked, so only the outer 12 ETH execution is counted.
        assertEq(spentToday, 12 ether, "nested reentry must not increase daily spending");
    }
}
