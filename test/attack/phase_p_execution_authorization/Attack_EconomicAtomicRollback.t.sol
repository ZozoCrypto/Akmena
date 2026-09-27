// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract RevertingEconomicTarget {
    error SimulatedEconomicFailure();

    function execute(uint256) external pure {
        revert SimulatedEconomicFailure();
    }
}

contract AttackEconomicAtomicRollbackTest is Test {
    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;

    address internal operator = address(0x1111);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    RevertingEconomicTarget internal target;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        authorization = boundary.executionAuthorization();

        target = new RevertingEconomicTarget();

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 10 ether, 100 ether, false);
    }

    function _intent(bytes memory payload, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(target),
            selector: RevertingEconomicTarget.execute.selector,
            asset: address(0),
            calldataHash: keccak256(payload),
            amount: 5 ether,
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

    function test_FailedExecutionRollsBackPolicySpend() public {
        bytes memory payload = abi.encodeWithSelector(RevertingEconomicTarget.execute.selector, 5 ether);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(payload, 0);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        vm.expectRevert(RevertingEconomicTarget.SimulatedEconomicFailure.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        (,, uint256 spentToday,,) = boundary.agentPolicies(operator, agent);

        assertEq(spentToday, 0, "CRITICAL: failed execution consumed policy budget");
    }

    function test_FailedExecutionDoesNotConsumeNonce() public {
        bytes memory payload = abi.encodeWithSelector(RevertingEconomicTarget.execute.selector, 5 ether);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(payload, 0);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        vm.expectRevert(RevertingEconomicTarget.SimulatedEconomicFailure.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        /*
         * The reverted transaction must roll back the nonce
         * consumption inside AkmenaExecutionAuthorization.
         *
         * Prove it by retrying the exact same signed intent.
         */
        vm.prank(agent);

        vm.expectRevert(RevertingEconomicTarget.SimulatedEconomicFailure.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);
    }
}
