// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {
    AkmenaCore
} from "../../../src/core/AkmenaCore.sol";

import {
    PrivacyEngine
} from "../../../src/privacy/PrivacyEngine.sol";

import {
    AkmenaPolicyBoundary
} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {
    AkmenaExecutionAuthorization
} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";


contract TransientMockTarget {
    uint256 public calls;

    function ping()
        external
        returns (bool)
    {
        calls++;
        return true;
    }
}


contract IntegrationTransientBoundaryTest is Test {
    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    address internal operator =
        address(0xBBBB);

    bytes32 internal constant PRIVACY_KEY =
        keccak256("PRIVACY_ENGINE");

    AkmenaCore internal core;
    PrivacyEngine internal privacy;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    TransientMockTarget internal target;


    function setUp() public {
        agent =
            vm.addr(AGENT_KEY);

        core =
            new AkmenaCore();

        privacy =
            new PrivacyEngine();

        boundary =
            new AkmenaPolicyBoundary(
                address(core)
            );

        authorization =
            boundary.executionAuthorization();

        target =
            new TransientMockTarget();

        core.registerModule(
            PRIVACY_KEY,
            address(privacy),
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


    function _intent(
        bytes memory payload,
        bytes32 nullifierHash,
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
                selector: TransientMockTarget.ping.selector,
                calldataHash: keccak256(payload),
                amount: amount,
                value: 0,
                proofModuleKey: PRIVACY_KEY,
                proofId: uint256(nullifierHash),
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

        return
            abi.encodePacked(
                r,
                s,
                v
            );
    }


    function test_ProofSuccessfullyPassesBoundary()
        public
    {
        bytes32 secret =
            keccak256("agent-secret");

        bytes32 nullifierHash =
            keccak256("workflow-002");

        uint256 amount =
            5 ether;

        bytes32 commitment =
            keccak256(
                abi.encodePacked(
                    nullifierHash,
                    secret,
                    amount
                )
            );

        bytes memory payload =
            abi.encodeWithSelector(
                TransientMockTarget.ping.selector
            );

        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                _intent(
                    payload,
                    nullifierHash,
                    amount,
                    0
                );

        bytes memory signature =
            _sign(intent);

        /*
         * Fund the PrivacyEngine commitment.
         */
        vm.deal(
            agent,
            10 ether
        );

        vm.prank(agent);

        privacy.depositPrivateEscrow{value: amount}(
            commitment
        );

        /*
         * IMPORTANT:
         *
         * PrivacyEngine writes its transient proof in this
         * execution transaction. The same transaction then
         * enters the canonical PolicyBoundary.
         *
         * The proof subject is the same canonical agent that
         * calls the boundary.
         */
        vm.prank(agent);

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            payable(agent)
        );

        /*
         * Canonical signed execution consumes the transient
         * proof produced immediately above.
         */
        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            intent,
            payload,
            signature
        );

        assertEq(
            target.calls(),
            1,
            "canonical execution did not pass transient proof"
        );
    }


    function test_TransientProofCanBackMultipleSeparatelyAuthorizedIntentsInSameTransaction()
        public
    {
        bytes32 secret =
            keccak256("same-tx-secret");

        bytes32 nullifierHash =
            keccak256("same-tx-nullifier");

        uint256 amount =
            1 ether;

        bytes32 commitment =
            keccak256(
                abi.encodePacked(
                    nullifierHash,
                    secret,
                    amount
                )
            );

        vm.deal(
            agent,
            5 ether
        );

        vm.prank(agent);

        privacy.depositPrivateEscrow{value: amount}(
            commitment
        );

        /*
         * Create the transient proof.
         */
        vm.prank(agent);

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            payable(agent)
        );

        /*
         * First authorized execution.
         */
        bytes memory firstPayload =
            abi.encodeWithSelector(
                TransientMockTarget.ping.selector
            );

        AkmenaExecutionAuthorization.ExecutionIntent
            memory firstIntent =
                _intent(
                    firstPayload,
                    nullifierHash,
                    amount,
                    1
                );

        bytes memory firstSignature =
            _sign(firstIntent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            firstIntent,
            firstPayload,
            firstSignature
        );

        assertEq(
            target.calls(),
            1
        );

        /*
         * Attempt a second distinct authorization using the
         * same transient proof but a different nonce.
         *
         * The proof itself remains transaction-scoped and is
         * still present. The question is whether canonical
         * execution authorization / policy accounting prevents
         * unintended reuse.
         */
        AkmenaExecutionAuthorization.ExecutionIntent
            memory secondIntent =
                _intent(
                    firstPayload,
                    nullifierHash,
                    amount,
                    2
                );

        bytes memory secondSignature =
            _sign(secondIntent);

        /*
         * EIP-1153 transient state lasts for the entire
         * transaction, not for a single call frame.
         *
         * Therefore the privacy proof may remain available
         * to subsequent canonical executions in this same
         * transaction.
         *
         * Security is provided by the independently signed
         * ExecutionIntent, including its nonce and complete
         * execution context.
         */
        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            secondIntent,
            firstPayload,
            secondSignature
        );

        assertEq(
            target.calls(),
            2,
            "second separately authorized execution did not occur"
        );
    }

    function test_TransientProofCanBackSeparatelyAuthorizedDifferentTarget()
        public
    {
        bytes32 secret =
            keccak256("cross-target-secret");

        bytes32 nullifierHash =
            keccak256("cross-target-nullifier");

        uint256 amount =
            1 ether;

        bytes32 commitment =
            keccak256(
                abi.encodePacked(
                    nullifierHash,
                    secret,
                    amount
                )
            );

        TransientMockTarget secondTarget =
            new TransientMockTarget();

        vm.deal(
            agent,
            5 ether
        );

        vm.prank(agent);

        privacy.depositPrivateEscrow{value: amount}(
            commitment
        );

        /*
         * Produce the single privacy proof.
         */
        vm.prank(agent);

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            payable(agent)
        );

        bytes memory firstPayload =
            abi.encodeWithSelector(
                TransientMockTarget.ping.selector
            );

        AkmenaExecutionAuthorization.ExecutionIntent
            memory firstIntent =
                _intent(
                    firstPayload,
                    nullifierHash,
                    amount,
                    10
                );

        bytes memory firstSignature =
            _sign(firstIntent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            firstIntent,
            firstPayload,
            firstSignature
        );

        assertEq(
            target.calls(),
            1
        );

        /*
         * A fresh signature now explicitly authorizes a
         * different target while retaining the same privacy
         * proof identity.
         */
        AkmenaExecutionAuthorization.ExecutionIntent
            memory secondIntent =
                AkmenaExecutionAuthorization.ExecutionIntent({
                    operator: operator,
                    agent: agent,
                    target: address(secondTarget),
                    selector: TransientMockTarget.ping.selector,
                    calldataHash: keccak256(firstPayload),
                    amount: amount,
                    value: 0,
                    proofModuleKey: PRIVACY_KEY,
                    proofId: uint256(nullifierHash),
                    nonce: 11,
                    validAfter: block.timestamp,
                    deadline: block.timestamp + 1 hours
                });

        bytes memory secondSignature =
            _sign(secondIntent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            secondIntent,
            firstPayload,
            secondSignature
        );

        /*
         * This demonstrates the intended separation:
         *
         * privacy proof = prerequisite/context
         * signed ExecutionIntent = actual execution authority
         */
        assertEq(
            target.calls(),
            1
        );

        assertEq(
            secondTarget.calls(),
            1,
            "separately authorized second target did not execute"
        );
    }

}
