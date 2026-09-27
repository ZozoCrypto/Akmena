// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract EconomicAdapter {
    uint256 public executedAmount;
    uint256 public calls;

    error EconomicAmountMismatch();

    function execute(uint256 declaredIntentAmount, uint256 actualEconomicAmount) external returns (bool) {
        if (declaredIntentAmount != actualEconomicAmount) {
            revert EconomicAmountMismatch();
        }

        executedAmount += actualEconomicAmount;

        calls++;

        return true;
    }
}

contract AttackEconomicAdapterBindingTest is Test {
    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;
    address internal operator = address(0x1111);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    EconomicAdapter internal target;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        authorization = boundary.executionAuthorization();

        target = new EconomicAdapter();

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 10 ether, 100 ether, false);
    }

    function _intent(bytes memory payload, uint256 amount, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(target),
            selector: EconomicAdapter.execute.selector,
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

    function test_MatchingEconomicSemanticsExecute() public {
        bytes memory payload = abi.encodeWithSelector(EconomicAdapter.execute.selector, 5 ether, 5 ether);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(payload, 5 ether, 0);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.executedAmount(), 5 ether);

        assertEq(target.calls(), 1);
    }

    function test_MismatchedEconomicSemanticsFailAtAdapter() public {
        bytes memory payload = abi.encodeWithSelector(EconomicAdapter.execute.selector, 1 ether, 100 ether);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(payload, 1 ether, 1);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        vm.expectRevert(EconomicAdapter.EconomicAmountMismatch.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.executedAmount(), 0);

        assertEq(target.calls(), 0);
    }

    function test_CalldataMutationStillFailsBeforeAdapter() public {
        bytes memory authorizedPayload = abi.encodeWithSelector(EconomicAdapter.execute.selector, 5 ether, 5 ether);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(authorizedPayload, 5 ether, 2);

        bytes memory signature = _sign(intent);

        bytes memory mutatedPayload = abi.encodeWithSelector(EconomicAdapter.execute.selector, 5 ether, 100 ether);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(intent, mutatedPayload, signature);

        assertEq(target.calls(), 0);
    }
}
