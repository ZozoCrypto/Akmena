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

import {
    EscrowEngine
} from "../../../src/economics/EscrowEngine.sol";


contract EscrowTargetA {
    uint256 public calls;

    function execute()
        external
    {
        calls++;
    }
}


contract EscrowTargetB {
    uint256 public calls;

    function execute()
        external
    {
        calls++;
    }
}


contract AttackCanonicalEscrowSemanticsTest is Test {
    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;
    address internal operator =
        address(0x1111);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    EscrowEngine internal escrow;

    EscrowTargetA internal targetA;
    EscrowTargetB internal targetB;

    bytes32 internal constant ESCROW_KEY =
        keccak256("ESCROW_ENGINE");


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

        escrow =
            new EscrowEngine();

        targetA =
            new EscrowTargetA();

        targetB =
            new EscrowTargetB();

        core.registerModule(
            ESCROW_KEY,
            address(escrow),
            "1.0.0"
        );

        vm.prank(operator);

        boundary.setAgentPolicy(
            agent,
            10 ether,
            100 ether,
            true
        );
    }


    function _payloadA()
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            EscrowTargetA.execute.selector
        );
    }


    function _payloadB()
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            EscrowTargetB.execute.selector
        );
    }


    function _intent(
        address target,
        bytes memory payload,
        uint256 amount,
        uint256 proofId,
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
                target: target,
                selector: bytes4(payload),
                calldataHash: keccak256(payload),
                amount: amount,
                value: 0,
                proofModuleKey: ESCROW_KEY,
                proofId: proofId,
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
            authorization.hashIntent(
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


    function _createEscrow(
        uint256 amount
    )
        internal
        returns (uint256)
    {
        vm.prank(operator);

        return escrow.createEscrow(
            address(0xCAFE),
            agent,
            amount
        );
    }


    function test_CanonicalEscrowRequiresAgentAsSeller()
        public
    {
        uint256 escrowId =
            _createEscrow(1 ether);

        bytes memory payload =
            _payloadA();

        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                _intent(
                    address(targetA),
                    payload,
                    1 ether,
                    escrowId,
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
            targetA.calls(),
            1
        );
    }


    function test_EscrowAmountMustMatchIntentAmount()
        public
    {
        uint256 escrowId =
            _createEscrow(1 ether);

        bytes memory payload =
            _payloadA();

        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                _intent(
                    address(targetA),
                    payload,
                    2 ether,
                    escrowId,
                    1
                );

        bytes memory signature =
            _sign(intent);

        vm.prank(agent);

        vm.expectRevert(
            AkmenaPolicyBoundary
                .InvalidTransientProof
                .selector
        );

        boundary.executeAuthorizedAgentCall(
            intent,
            payload,
            signature
        );

        assertEq(
            targetA.calls(),
            0
        );
    }


    function test_EscrowProofDoesNotAuthorizeWrongAgent()
        public
    {
        address otherAgent =
            address(0x2222);

        uint256 escrowId =
            _createEscrow(1 ether);

        bytes memory payload =
            _payloadA();

        AkmenaExecutionAuthorization
            .ExecutionIntent
            memory intent =
                _intent(
                    address(targetA),
                    payload,
                    1 ether,
                    escrowId,
                    2
                );

        bytes memory signature =
            _sign(intent);

        /*
         * The signature itself is from `agent`, but the
         * actual caller is a different address.
         */
        vm.prank(otherAgent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(
            intent,
            payload,
            signature
        );

        assertEq(
            targetA.calls(),
            0
        );
    }


    function test_SameEscrowCanBackDifferentSignedTargetIntent()
        public
    {
        uint256 escrowId =
            _createEscrow(1 ether);

        bytes memory payloadA =
            _payloadA();

        AkmenaExecutionAuthorization
            .ExecutionIntent
            memory intentA =
                _intent(
                    address(targetA),
                    payloadA,
                    1 ether,
                    escrowId,
                    3
                );

        bytes memory signatureA =
            _sign(intentA);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            intentA,
            payloadA,
            signatureA
        );

        assertEq(
            targetA.calls(),
            1
        );

        /*
         * Same active escrow.
         *
         * Completely different target.
         *
         * Fresh signature.
         *
         * Different nonce.
         *
         * If this succeeds, the escrow proof is a prerequisite
         * rather than target-specific authorization.
         */
        bytes memory payloadB =
            _payloadB();

        AkmenaExecutionAuthorization
            .ExecutionIntent
            memory intentB =
                _intent(
                    address(targetB),
                    payloadB,
                    1 ether,
                    escrowId,
                    4
                );

        bytes memory signatureB =
            _sign(intentB);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            intentB,
            payloadB,
            signatureB
        );

        assertEq(
            targetB.calls(),
            1
        );
    }
}
