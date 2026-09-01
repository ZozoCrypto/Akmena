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

contract ProductionEconomicTarget {
    uint256 public lastAmount;
    address public lastRecipient;
    uint256 public callCount;

    function transferLike(
        address recipient,
        uint256 amount
    )
        external
        returns (bool)
    {
        lastRecipient = recipient;
        lastAmount = amount;
        callCount += 1;

        return true;
    }
}

contract AttackProductionEconomicBindingTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    ProductionEconomicTarget internal target;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;
    address internal operator =
        address(0x1111);

    address internal recipient =
        address(0xBBBB);

    function setUp() public {
        core = new AkmenaCore();

        boundary =
            new AkmenaPolicyBoundary(
                address(core)
            );

        authorization =
            boundary.executionAuthorization();

        target =
            new ProductionEconomicTarget();

        agent =
            vm.addr(AGENT_KEY);

        vm.prank(operator);

        boundary.setAgentPolicy(
            agent,
            100 ether,
            100 ether,
            false
        );
    }

    function _intent(
        uint256 declaredAmount,
        uint256 nonce
    )
        internal
        view
        returns (
            AkmenaExecutionAuthorization.ExecutionIntent memory
        )
    {
        bytes memory payload =
            abi.encodeWithSelector(
                ProductionEconomicTarget.transferLike.selector,
                recipient,
                declaredAmount
            );

        return
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: operator,
                agent: agent,
                target: address(target),
                selector:
                    ProductionEconomicTarget.transferLike.selector,
                calldataHash:
                    keccak256(payload),
                amount: declaredAmount,
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

    function test_ProductionBoundaryBindsEconomicPayload()
        public
    {
        uint256 signedAmount =
            1 ether;

        uint256 actualPayloadAmount =
            50 ether;

        bytes memory signedPayload =
            abi.encodeWithSelector(
                ProductionEconomicTarget.transferLike.selector,
                recipient,
                signedAmount
            );

        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                AkmenaExecutionAuthorization.ExecutionIntent({
                    operator: operator,
                    agent: agent,
                    target: address(target),
                    selector:
                        ProductionEconomicTarget.transferLike.selector,
                    calldataHash:
                        keccak256(signedPayload),
                    amount: signedAmount,
                    value: 0,
                    proofModuleKey: bytes32(0),
                    proofId: 0,
                    nonce: 0,
                    validAfter: block.timestamp,
                    deadline: block.timestamp + 1 hours
                });

        bytes memory signature =
            _sign(intent);

        bytes memory substitutedPayload =
            abi.encodeWithSelector(
                ProductionEconomicTarget.transferLike.selector,
                recipient,
                actualPayloadAmount
            );

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(
            intent,
            substitutedPayload,
            signature
        );

        assertEq(
            target.callCount(),
            0,
            "CRITICAL: production boundary accepted economic calldata substitution"
        );
    }

    function test_ProductionBoundaryAcceptsMatchingEconomicPayload()
        public
    {
        uint256 amount =
            1 ether;

        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                _intent(
                    amount,
                    1
                );

        bytes memory payload =
            abi.encodeWithSelector(
                ProductionEconomicTarget.transferLike.selector,
                recipient,
                amount
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
            target.callCount(),
            1
        );

        assertEq(
            target.lastRecipient(),
            recipient
        );

        assertEq(
            target.lastAmount(),
            amount
        );
    }
}
