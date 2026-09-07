// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {Test} from "forge-std/Test.sol";

import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

/*
 * Simulates a downstream module that incorrectly assumes
 * msg.sender is the agent whose execution was authorized.
 */
contract MsgSenderAuthorityModule {
    address public authorizedOwner;
    uint256 public successfulCalls;

    error Unauthorized();

    constructor(address owner_) {
        authorizedOwner = owner_;
    }

    function privilegedAction() external returns (bool) {
        if (msg.sender != authorizedOwner) {
            revert Unauthorized();
        }

        successfulCalls++;
        return true;
    }
}

contract AttackDownstreamAuthorityConfusionTest is Test {
    AkmenaPolicyBoundary internal boundary;
    AkmenaCore internal core;
    MsgSenderAuthorityModule internal module;

    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;
    address internal operator = address(0xBBBB);

    function setUp() public {
        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        agent = vm.addr(AGENT_KEY);

        module = new MsgSenderAuthorityModule(agent);

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 10 ether, 20 ether, false);
    }

    function _intent(bytes memory payload) internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory) {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(module),
            selector: MsgSenderAuthorityModule.privilegedAction.selector,
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

    function test_DirectAgentCallSucceeds() public {
        vm.prank(agent);

        module.privilegedAction();

        assertEq(module.successfulCalls(), 1);
    }

    function test_CanonicalBoundaryCallCannotPreserveMsgSender() public {
        bytes memory payload = abi.encodeWithSelector(MsgSenderAuthorityModule.privilegedAction.selector);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(payload);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        vm.expectRevert(MsgSenderAuthorityModule.Unauthorized.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(module.successfulCalls(), 0);
    }

    function test_ValidAgentAuthorizationDoesNotBecomeDownstreamAgentIdentity() public {
        bytes memory payload = abi.encodeWithSelector(MsgSenderAuthorityModule.privilegedAction.selector);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(payload);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        vm.expectRevert(MsgSenderAuthorityModule.Unauthorized.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        /*
         * The cryptographic authorization was valid.
         *
         * The failure occurs because downstream msg.sender
         * is the PolicyBoundary, not the agent.
         */
        assertEq(module.successfulCalls(), 0);
    }
}
