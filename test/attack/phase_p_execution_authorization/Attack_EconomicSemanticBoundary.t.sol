// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {
    AkmenaCore
} from "../../../src/core/AkmenaCore.sol";

import {
    AkmenaPolicyBoundary
} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {
    AkmenaExecutionAuthorization
} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";


contract EconomicSemanticTarget {
    uint256 public executedAmount;
    uint256 public calls;

    function execute(uint256 amount)
        external
        returns (bool)
    {
        executedAmount += amount;
        calls++;

        return true;
    }
}


contract AttackEconomicSemanticBoundaryTest is Test {
    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;
    address internal operator =
        address(0x1111);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    EconomicSemanticTarget internal target;


    function setUp() public {
        agent =
            vm.addr(AGENT_KEY);

        core =
            new AkmenaCore();

        boundary =
            new AkmenaPolicyBoundary(
                address(core)
            );

        authorization =
            boundary.executionAuthorization();

        target =
            new EconomicSemanticTarget();

        vm.prank(operator);

        boundary.setAgentPolicy(
            agent,
            1 ether,
            10 ether,
            false
        );
    }


    function _intent(
        bytes memory payload,
        uint256 amount,
        uint256 nonce
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
                target: address(target),
                selector: EconomicSemanticTarget.execute.selector,
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


    function _sign(
        AkmenaExecutionAuthorization.ExecutionIntent memory intent
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            authorization.hashIntent(intent);

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


    function test_ExactEconomicAmountExecutes()
        public
    {
        bytes memory payload =
            abi.encodeWithSelector(
                EconomicSemanticTarget.execute.selector,
                1 ether
            );

        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                _intent(
                    payload,
                    1 ether,
                    0
                );

        bytes memory signature =
            _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            intent,
            payload,
            signature
        );

        assertEq(
            target.executedAmount(),
            1 ether
        );

        (
            ,
            ,
            uint256 spentToday,
            ,
        ) =
            boundary.agentPolicies(
                operator,
                agent
            );

        assertEq(
            spentToday,
            1 ether
        );
    }


    function test_SignedIntentCanAuthorizeCalldataWithDifferentEconomicParameter()
        public
    {
        bytes memory payload =
            abi.encodeWithSelector(
                EconomicSemanticTarget.execute.selector,
                100 ether
            );

        /*
         * The generic execution boundary is being asked to
         * account only 1 ETH while the downstream call itself
         * carries a 100 ETH semantic parameter.
         */
        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                _intent(
                    payload,
                    1 ether,
                    1
                );

        bytes memory signature =
            _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            intent,
            payload,
            signature
        );

        assertEq(
            target.executedAmount(),
            100 ether,
            "downstream economic parameter was not executed"
        );

        (
            ,
            ,
            uint256 spentToday,
            ,
        ) =
            boundary.agentPolicies(
                operator,
                agent
            );

        assertEq(
            spentToday,
            1 ether,
            "policy accounting should reflect signed intent amount"
        );
    }


    function test_ChangingPayloadRequiresNewAuthorization()
        public
    {
        bytes memory authorizedPayload =
            abi.encodeWithSelector(
                EconomicSemanticTarget.execute.selector,
                1 ether
            );

        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                _intent(
                    authorizedPayload,
                    1 ether,
                    2
                );

        bytes memory signature =
            _sign(intent);

        bytes memory substitutedPayload =
            abi.encodeWithSelector(
                EconomicSemanticTarget.execute.selector,
                100 ether
            );

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(
            intent,
            substitutedPayload,
            signature
        );

        assertEq(
            target.executedAmount(),
            0
        );
    }
}
