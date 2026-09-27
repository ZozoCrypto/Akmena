// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../src/core/AkmenaCore.sol";

import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";

import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";

contract DummyTarget {
    uint256 public calls;

    function ping() external returns (bool) {
        calls++;
        return true;
    }
}

contract AkmenaPolicyBoundaryUnitTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    DummyTarget internal target;

    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal humanOperator = address(0x111);

    address internal aiAgentHotWallet;

    function setUp() public {
        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        authorization = boundary.executionAuthorization();

        target = new DummyTarget();

        aiAgentHotWallet = vm.addr(AGENT_KEY);
    }

    function _intent(uint256 amount, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        bytes memory payload = abi.encodeWithSelector(DummyTarget.ping.selector);

        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: humanOperator,
            agent: aiAgentHotWallet,
            target: address(target),
            selector: DummyTarget.ping.selector,
            asset: address(0),
            calldataHash: keccak256(payload),
            amount: amount,
            value: 0,
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

    function test_SetAndExecutePolicy() public {
        uint256 amount = 50 ether;

        vm.prank(humanOperator);

        boundary.setAgentPolicy(aiAgentHotWallet, 100 ether, 1000 ether, false);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(amount, 0);

        bytes memory payload = abi.encodeWithSelector(DummyTarget.ping.selector);

        bytes memory signature = _sign(intent);

        vm.prank(aiAgentHotWallet);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 1, "canonical authorized execution did not occur");

        (uint256 maxSpend, uint256 dailyLimit, uint256 spentToday,, bool requireEscrow) =
            boundary.agentPolicies(humanOperator, aiAgentHotWallet);

        assertEq(maxSpend, 100 ether);

        assertEq(dailyLimit, 1000 ether);

        assertEq(spentToday, amount);

        assertFalse(requireEscrow);
    }

    function test_AgentCannotExecuteWithoutPolicy() public {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(1 ether, 0);

        bytes memory payload = abi.encodeWithSelector(DummyTarget.ping.selector);

        bytes memory signature = _sign(intent);

        vm.prank(aiAgentHotWallet);

        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAgent.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 0);
    }

    function test_ExecutionAbovePerTransactionLimitReverts() public {
        vm.prank(humanOperator);

        boundary.setAgentPolicy(aiAgentHotWallet, 10 ether, 100 ether, false);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(11 ether, 0);

        bytes memory payload = abi.encodeWithSelector(DummyTarget.ping.selector);

        bytes memory signature = _sign(intent);

        vm.prank(aiAgentHotWallet);

        vm.expectRevert(AkmenaPolicyBoundary.PolicyExceeded.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 0);
    }

    function test_ExecutionAboveDailyLimitReverts() public {
        vm.prank(humanOperator);

        boundary.setAgentPolicy(aiAgentHotWallet, 100 ether, 100 ether, false);

        AkmenaExecutionAuthorization.ExecutionIntent memory first = _intent(60 ether, 0);

        bytes memory payload = abi.encodeWithSelector(DummyTarget.ping.selector);

        bytes memory firstSignature = _sign(first);

        vm.prank(aiAgentHotWallet);

        boundary.executeAuthorizedAgentCall(first, payload, firstSignature);

        AkmenaExecutionAuthorization.ExecutionIntent memory second = _intent(41 ether, 1);

        bytes memory secondSignature = _sign(second);

        vm.prank(aiAgentHotWallet);

        vm.expectRevert(AkmenaPolicyBoundary.PolicyExceeded.selector);

        boundary.executeAuthorizedAgentCall(second, payload, secondSignature);

        assertEq(target.calls(), 1);
    }

    function test_PausedCoreBlocksAuthorizedExecution() public {
        uint256 amount = 1 ether;

        vm.prank(humanOperator);
        boundary.setAgentPolicy(aiAgentHotWallet, 10 ether, 10 ether, false);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(amount, 0);

        bytes memory payload = abi.encodeWithSelector(DummyTarget.ping.selector);

        bytes memory signature = _sign(intent);

        core.setPaused(true);

        vm.prank(aiAgentHotWallet);
        vm.expectRevert(AkmenaPolicyBoundary.ProtocolPaused.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 0);

        assertFalse(authorization.usedNonces(aiAgentHotWallet, 0));
    }

    function test_RevertWhen_CoreIsZero() public {
        vm.expectRevert(AkmenaPolicyBoundary.InvalidCore.selector);

        new AkmenaPolicyBoundary(address(0));
    }

    function test_RevertWhen_CoreHasNoCode() public {
        vm.expectRevert(AkmenaPolicyBoundary.InvalidCore.selector);

        new AkmenaPolicyBoundary(address(0xBEEF));
    }
}
