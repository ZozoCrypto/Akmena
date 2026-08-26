// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {
    AkmenaExecutionAuthorization
} from "../../src/authorization/AkmenaExecutionAuthorization.sol";

contract AkmenaExecutionAuthorizationTest is Test {

    AkmenaExecutionAuthorization internal auth;

    uint256 internal agentPrivateKey =
        0xA11CE;

    uint256 internal attackerPrivateKey =
        0xB0B;

    address internal agent;
    address internal attacker;

    address internal constant OPERATOR =
        address(0x1111);

    address internal constant TARGET =
        address(0x2222);

    bytes32 internal constant PROOF_DOMAIN =
        keccak256("akmena.proof.escrow");

    function setUp()
        public
    {
        auth =
            new AkmenaExecutionAuthorization();

        agent =
            vm.addr(agentPrivateKey);

        attacker =
            vm.addr(attackerPrivateKey);
    }

    function _payload(
        uint256 amount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "execute(uint256)",
            amount
        );
    }

    function _intent(
        uint256 nonce,
        uint256 amount
    )
        internal
        view
        returns (
            AkmenaExecutionAuthorization.ExecutionIntent memory
        )
    {
        bytes memory payload =
            _payload(amount);

        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: OPERATOR,
            agent: agent,
            target: TARGET,
            selector: bytes4(
                keccak256("execute(uint256)")
            ),
            calldataHash: keccak256(payload),
            amount: amount,
            value: 0,
            proofModuleKey: PROOF_DOMAIN,
            proofId: 1,
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(
        AkmenaExecutionAuthorization.ExecutionIntent memory intent,
        uint256 privateKey
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            auth.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(
                privateKey,
                digest
            );

        return abi.encodePacked(
            r,
            s,
            v
        );
    }

    function test_ValidAuthorizationAccepted()
        public
    {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(
                1,
                1 ether
            );

        bytes memory payload =
            _payload(1 ether);

        bytes memory signature =
            _sign(
                intent,
                agentPrivateKey
            );

        address recovered =
            auth.verifyAndConsume(
                intent,
                payload,
                0,
                signature
            );

        assertEq(
            recovered,
            agent
        );

        assertTrue(
            auth.usedNonces(
                agent,
                1
            )
        );
    }

    function test_ReplayRejected()
        public
    {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(
                1,
                1 ether
            );

        bytes memory payload =
            _payload(1 ether);

        bytes memory signature =
            _sign(
                intent,
                agentPrivateKey
            );

        auth.verifyAndConsume(
            intent,
            payload,
            0,
            signature
        );

        vm.expectRevert(
            AkmenaExecutionAuthorization
                .NonceAlreadyUsed
                .selector
        );

        auth.verifyAndConsume(
            intent,
            payload,
            0,
            signature
        );
    }

    function test_TargetMutationRejected()
        public
    {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(
                1,
                1 ether
            );

        bytes memory payload =
            _payload(1 ether);

        bytes memory signature =
            _sign(
                intent,
                agentPrivateKey
            );

        intent.target =
            address(0x9999);

        vm.expectRevert(
            AkmenaExecutionAuthorization
                .InvalidSigner
                .selector
        );

        auth.verifyAndConsume(
            intent,
            payload,
            0,
            signature
        );
    }

    function test_SelectorMutationRejected()
        public
    {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(
                1,
                1 ether
            );

        bytes memory payload =
            _payload(1 ether);

        bytes memory signature =
            _sign(
                intent,
                agentPrivateKey
            );

        intent.selector =
            bytes4(
                keccak256(
                    "different(uint256)"
                )
            );

        vm.expectRevert(
            AkmenaExecutionAuthorization
                .InvalidSelector
                .selector
        );

        auth.verifyAndConsume(
            intent,
            payload,
            0,
            signature
        );
    }

    function test_CalldataMutationRejected()
        public
    {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(
                1,
                1 ether
            );

        bytes memory originalPayload =
            _payload(1 ether);

        bytes memory substitutedPayload =
            _payload(100 ether);

        bytes memory signature =
            _sign(
                intent,
                agentPrivateKey
            );

        vm.expectRevert(
            AkmenaExecutionAuthorization
                .InvalidCalldataHash
                .selector
        );

        auth.verifyAndConsume(
            intent,
            substitutedPayload,
            0,
            signature
        );

        originalPayload;
    }

    function test_AmountMutationRejected()
        public
    {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(
                1,
                1 ether
            );

        bytes memory payload =
            _payload(1 ether);

        bytes memory signature =
            _sign(
                intent,
                agentPrivateKey
            );

        intent.amount =
            100 ether;

        vm.expectRevert(
            AkmenaExecutionAuthorization
                .InvalidSigner
                .selector
        );

        auth.verifyAndConsume(
            intent,
            payload,
            0,
            signature
        );
    }

    function test_ValueMutationRejected()
        public
    {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(
                1,
                1 ether
            );

        bytes memory payload =
            _payload(1 ether);

        bytes memory signature =
            _sign(
                intent,
                agentPrivateKey
            );

        intent.value =
            1 ether;

        vm.expectRevert(
            AkmenaExecutionAuthorization
                .InvalidCalldataHash
                .selector
        );

        auth.verifyAndConsume(
            intent,
            payload,
            0,
            signature
        );
    }

    function test_ActualValueMustMatchSignedValue()
        public
    {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(
                1,
                1 ether
            );

        bytes memory payload =
            _payload(1 ether);

        bytes memory signature =
            _sign(
                intent,
                agentPrivateKey
            );

        vm.expectRevert(
            AkmenaExecutionAuthorization
                .InvalidCalldataHash
                .selector
        );

        auth.verifyAndConsume(
            intent,
            payload,
            1 ether,
            signature
        );
    }

    function test_AttackerSignatureRejected()
        public
    {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(
                1,
                1 ether
            );

        bytes memory payload =
            _payload(1 ether);

        bytes memory signature =
            _sign(
                intent,
                attackerPrivateKey
            );

        vm.expectRevert(
            AkmenaExecutionAuthorization
                .InvalidSigner
                .selector
        );

        auth.verifyAndConsume(
            intent,
            payload,
            0,
            signature
        );
    }

    function test_ExpiredAuthorizationRejected()
        public
    {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(
                1,
                1 ether
            );

        bytes memory payload =
            _payload(1 ether);

        bytes memory signature =
            _sign(
                intent,
                agentPrivateKey
            );

        vm.warp(
            block.timestamp + 2 hours
        );

        vm.expectRevert(
            AkmenaExecutionAuthorization
                .AuthorizationExpired
                .selector
        );

        auth.verifyAndConsume(
            intent,
            payload,
            0,
            signature
        );
    }

    function test_NotYetValidRejected()
        public
    {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(
                1,
                1 ether
            );

        intent.validAfter =
            block.timestamp + 1 hours;

        bytes memory payload =
            _payload(1 ether);

        bytes memory signature =
            _sign(
                intent,
                agentPrivateKey
            );

        vm.expectRevert(
            AkmenaExecutionAuthorization
                .AuthorizationNotYetValid
                .selector
        );

        auth.verifyAndConsume(
            intent,
            payload,
            0,
            signature
        );
    }
}
