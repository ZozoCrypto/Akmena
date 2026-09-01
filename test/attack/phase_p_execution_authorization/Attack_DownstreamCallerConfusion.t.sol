// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {
    AkmenaPolicyBoundary
} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {
    AkmenaCore
} from "../../../src/core/AkmenaCore.sol";

import {
    AkmenaExecutionAuthorization
} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";


contract CallerProbe {
    address public observedSender;
    address public observedExpectedAgent;
    bytes32 public observedWorkflowId;

    function probe(
        address expectedAgent,
        bytes32 workflowId
    )
        external
        returns (bool)
    {
        observedSender = msg.sender;
        observedExpectedAgent = expectedAgent;
        observedWorkflowId = workflowId;

        return true;
    }
}


contract AttackDownstreamCallerConfusionTest is Test {
    AkmenaPolicyBoundary internal boundary;
    AkmenaCore internal core;
    CallerProbe internal probe;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    address internal operator =
        address(0xBBBB);

    bytes32 internal workflowId =
        keccak256("workflow");


    function setUp() public {
        core = new AkmenaCore();

        boundary =
            new AkmenaPolicyBoundary(
                address(core)
            );

        probe =
            new CallerProbe();

        agent =
            vm.addr(AGENT_KEY);

        vm.prank(operator);

        boundary.setAgentPolicy(
            agent,
            10 ether,
            20 ether,
            false
        );
    }


    function _intent(
        bytes memory payload
    )
        internal
        view
        returns (
            AkmenaExecutionAuthorization.ExecutionIntent memory
        )
    {
        return
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: operator,
                agent: agent,
                target: address(probe),
                selector: CallerProbe.probe.selector,
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


    function _sign(
        AkmenaExecutionAuthorization.ExecutionIntent memory intent
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            boundary.executionAuthorization().hashIntent(
                intent
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                AGENT_KEY,
                digest
            );

        return abi.encodePacked(
            r,
            s,
            v
        );
    }


    function test_DirectCallUsesAgentAsMsgSender()
        public
    {
        vm.prank(agent);

        probe.probe(
            agent,
            workflowId
        );

        assertEq(
            probe.observedSender(),
            agent
        );

        assertEq(
            probe.observedExpectedAgent(),
            agent
        );

        assertEq(
            probe.observedWorkflowId(),
            workflowId
        );
    }


    function test_CanonicalBoundaryCallChangesDownstreamMsgSender()
        public
    {
        bytes memory payload =
            abi.encodeWithSelector(
                CallerProbe.probe.selector,
                agent,
                workflowId
            );

        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                _intent(payload);

        bytes memory signature =
            _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            intent,
            payload,
            signature
        );

        // The downstream contract is NOT called directly
        // by the agent. The policy boundary is the immediate
        // caller at the EVM level.
        assertEq(
            probe.observedSender(),
            address(boundary)
        );

        // The signed/payload-level identity remains the agent.
        assertEq(
            probe.observedExpectedAgent(),
            agent
        );

        assertEq(
            probe.observedWorkflowId(),
            workflowId
        );
    }


    function test_DownstreamCannotMistakeBoundaryForAgent()
        public
    {
        bytes memory payload =
            abi.encodeWithSelector(
                CallerProbe.probe.selector,
                agent,
                workflowId
            );

        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                _intent(payload);

        bytes memory signature =
            _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            intent,
            payload,
            signature
        );

        assertTrue(
            probe.observedSender() != agent
        );

        assertEq(
            probe.observedSender(),
            address(boundary)
        );

        assertEq(
            probe.observedExpectedAgent(),
            agent
        );
    }
}
