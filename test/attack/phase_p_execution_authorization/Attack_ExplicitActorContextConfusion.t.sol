// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {Test} from "forge-std/Test.sol";

import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract ActorContextProbe {
    address public observedSender;
    address public observedActor;
    bytes32 public observedWorkflowId;

    function consumeContext(address actor, bytes32 workflowId) external returns (bool) {
        observedSender = msg.sender;
        observedActor = actor;
        observedWorkflowId = workflowId;

        return true;
    }
}

contract AttackExplicitActorContextConfusionTest is Test {
    AkmenaPolicyBoundary internal boundary;
    AkmenaCore internal core;
    ActorContextProbe internal probe;

    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;
    address internal operator = address(0xBBBB);

    bytes32 internal workflowId = keccak256("workflow");

    function setUp() public {
        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        agent = vm.addr(AGENT_KEY);

        probe = new ActorContextProbe();

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 10 ether, 20 ether, false);
    }

    function _intent(bytes memory payload) internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory) {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(probe),
            selector: ActorContextProbe.consumeContext.selector,
            calldataHash: keccak256(payload),
            amount: 0,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: 0,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = boundary.executionAuthorization().hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_ExplicitActorPayloadCanRepresentAuthorizedAgent() public {
        bytes memory payload = abi.encodeWithSelector(ActorContextProbe.consumeContext.selector, agent, workflowId);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(payload);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(probe.observedActor(), agent);

        assertEq(probe.observedWorkflowId(), workflowId);

        assertEq(probe.observedSender(), address(boundary));
    }

    function test_ChangingActorInvalidatesAuthorization() public {
        bytes memory authorizedPayload =
            abi.encodeWithSelector(ActorContextProbe.consumeContext.selector, agent, workflowId);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(authorizedPayload);

        bytes memory signature = _sign(intent);

        bytes memory mutatedPayload =
            abi.encodeWithSelector(ActorContextProbe.consumeContext.selector, address(0xDEAD), workflowId);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(intent, mutatedPayload, signature);
    }

    function test_ChangingWorkflowContextInvalidatesAuthorization() public {
        bytes memory authorizedPayload =
            abi.encodeWithSelector(ActorContextProbe.consumeContext.selector, agent, workflowId);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(authorizedPayload);

        bytes memory signature = _sign(intent);

        bytes memory mutatedPayload =
            abi.encodeWithSelector(ActorContextProbe.consumeContext.selector, agent, keccak256("different-workflow"));

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(intent, mutatedPayload, signature);
    }
}
