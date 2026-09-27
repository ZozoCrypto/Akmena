// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract PhaseNTarget {
    uint256 public calls;
    uint256 public valueReceived;
    bytes32 public lastData;

    function action(uint256 value) external {
        calls++;
        valueReceived += value;
        lastData = keccak256(msg.data);
    }

    function privileged() external {
        calls++;
        lastData = keccak256(msg.data);
    }
}

contract Attack_PolicyCompositionTest is Test {
    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;
    address internal operator = address(0x1111);

    address internal attacker = address(0x3333);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;

    PhaseNTarget internal target;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        authorization = boundary.executionAuthorization();

        target = new PhaseNTarget();

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 100 ether, 1000 ether, false);
    }

    function _payloadPrivileged() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(PhaseNTarget.privileged.selector);
    }

    function _intent(address targetAddress, bytes memory payload, uint256 amount, uint256 value, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: targetAddress,
            // forge-lint: disable-next-line(unsafe-typecast)
            selector: bytes4(payload),
            asset: address(0),
            calldataHash: keccak256(payload),
            amount: amount,
            value: value,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = authorization.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_Attack_OperatorSubstitution() public {
        bytes memory payload = _payloadPrivileged();

        AkmenaExecutionAuthorization.ExecutionIntent memory original = _intent(address(target), payload, 1 ether, 0, 1);

        bytes memory signature = _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory mutated = original;

        mutated.operator = attacker;

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(mutated, payload, signature);

        assertEq(target.calls(), 0);
    }

    function test_Attack_AgentSubstitution() public {
        bytes memory payload = _payloadPrivileged();

        AkmenaExecutionAuthorization.ExecutionIntent memory original = _intent(address(target), payload, 1 ether, 0, 2);

        bytes memory signature = _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory mutated = original;

        mutated.agent = attacker;

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(mutated, payload, signature);

        assertEq(target.calls(), 0);
    }

    function test_Attack_PolicyCannotAuthorizeDifferentSelector() public {
        bytes memory authorizedPayload = _payloadPrivileged();

        AkmenaExecutionAuthorization.ExecutionIntent memory original =
            _intent(address(target), authorizedPayload, 1 ether, 0, 3);

        bytes memory signature = _sign(original);

        bytes memory mutatedPayload = abi.encodeWithSelector(PhaseNTarget.action.selector, 100 ether);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(original, mutatedPayload, signature);

        assertEq(target.calls(), 0);

        assertEq(target.valueReceived(), 0);
    }

    function test_Attack_PolicyCannotAuthorizeDifferentCalldata() public {
        bytes memory authorizedPayload = abi.encodeWithSelector(PhaseNTarget.action.selector, 1 ether);

        AkmenaExecutionAuthorization.ExecutionIntent memory original =
            _intent(address(target), authorizedPayload, 1 ether, 0, 4);

        bytes memory signature = _sign(original);

        bytes memory mutatedPayload = abi.encodeWithSelector(PhaseNTarget.action.selector, 100 ether);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(original, mutatedPayload, signature);

        assertEq(target.calls(), 0);

        assertEq(target.valueReceived(), 0);
    }

    function test_Attack_PolicyCannotAuthorizeDifferentTarget() public {
        PhaseNTarget secondTarget = new PhaseNTarget();

        bytes memory payload = _payloadPrivileged();

        AkmenaExecutionAuthorization.ExecutionIntent memory original = _intent(address(target), payload, 1 ether, 0, 5);

        bytes memory signature = _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory mutated = original;

        mutated.target = address(secondTarget);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(mutated, payload, signature);

        assertEq(target.calls(), 0);

        assertEq(secondTarget.calls(), 0);
    }

    function test_ZeroSpendCanExecuteOnlyWhenExplicitlyAuthorized() public {
        /*
         * Zero economic spend is not itself an authorization
         * failure. A signed intent can legitimately authorize
         * a non-economic action.
         *
         * What matters is that the exact target and calldata
         * remain cryptographically bound to the intent.
         */
        bytes memory payload = _payloadPrivileged();

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(target), payload, 0, 0, 6);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 1);

        assertEq(target.valueReceived(), 0);
    }
}
