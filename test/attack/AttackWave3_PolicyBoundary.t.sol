// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";

import {AkmenaCore} from "../../src/core/AkmenaCore.sol";

import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";

import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";

import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";

contract Wave3Target {
    uint256 public calls;

    function ping() external returns (bool) {
        calls++;
        return true;
    }
}

contract AttackWave3_PolicyBoundaryTest is Test {
    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;
    address internal operator = address(0x1111);

    address internal attacker = address(0xBEEF);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    EscrowEngine internal escrow;
    Wave3Target internal target;

    bytes32 internal constant ESCROW_ENGINE = "ESCROW_ENGINE";

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        authorization = boundary.executionAuthorization();

        escrow = new EscrowEngine(address(new AkmenaToken(address(this))));

        target = new Wave3Target();

        core.registerModule(ESCROW_ENGINE, address(escrow), "2.1.0");

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 100 ether, 1000 ether, false);
    }

    function _intent(address callerAgent, uint256 amount, bytes32 proofModuleKey, uint256 proofId, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        bytes memory payload = abi.encodeWithSelector(Wave3Target.ping.selector);

        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: callerAgent,
            target: address(target),
            selector: Wave3Target.ping.selector,
            asset: address(0),
            calldataHash: keccak256(payload),
            amount: amount,
            value: 0,
            proofModuleKey: proofModuleKey,
            proofId: proofId,
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

    function test_Attack_UnauthorizedCallerCannotConsumeVictimDailyLimit() public {
        uint256 amount = 100 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(agent, amount, bytes32(0), 0, 1);

        bytes memory payload = abi.encodeWithSelector(Wave3Target.ping.selector);

        bytes memory signature = _sign(intent);

        vm.prank(attacker);

        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAgent.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 0);

        (,, uint256 spentToday,,) = boundary.agentPolicies(operator, agent);

        assertEq(spentToday, 0, "CRITICAL: unauthorized caller consumed victim policy");
    }

    function test_Attack_EscrowRequirementCannotBeSatisfiedByMissingEscrow() public {
        vm.prank(operator);

        boundary.setAgentPolicy(agent, 100 ether, 1000 ether, true);

        uint256 amount = 1 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(agent, amount, ESCROW_ENGINE, 999999, 2);

        bytes memory payload = abi.encodeWithSelector(Wave3Target.ping.selector);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 0);
    }

    function test_Attack_ArbitraryCallerCanSubmitVictimIdentity() public {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(agent, 1 ether, bytes32(0), 0, 3);

        bytes memory payload = abi.encodeWithSelector(Wave3Target.ping.selector);

        bytes memory signature = _sign(intent);

        vm.prank(attacker);

        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAgent.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 0);
    }
}
