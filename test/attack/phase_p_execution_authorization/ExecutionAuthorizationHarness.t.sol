// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract ExecutionAuthorizationHarness is EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant EXECUTION_INTENT_TYPEHASH =
        keccak256(
            "ExecutionIntent(address operator,address agent,address target,bytes4 selector,bytes32 calldataHash,uint256 amount,uint256 value,bytes32 proofModuleKey,uint256 proofId,uint256 nonce,uint256 deadline)"
        );

    struct ExecutionIntent {
        address operator;
        address agent;
        address target;
        bytes4 selector;
        bytes32 calldataHash;
        uint256 amount;
        uint256 value;
        bytes32 proofModuleKey;
        uint256 proofId;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(address => mapping(uint256 => bool)) public usedNonces;

    error InvalidSigner();
    error AuthorizationExpired();
    error AuthorizationNotYetValid();
    error NonceAlreadyUsed();

    constructor()
        EIP712("AkmenaExecutionAuthorization", "1")
    {}

    function hashIntent(
        ExecutionIntent memory intent
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                EXECUTION_INTENT_TYPEHASH,
                intent.operator,
                intent.agent,
                intent.target,
                intent.selector,
                intent.calldataHash,
                intent.amount,
                intent.value,
                intent.proofModuleKey,
                intent.proofId,
                intent.nonce,
                intent.deadline
            )
        );

        return _hashTypedDataV4(structHash);
    }

    function verifyAndConsume(
        ExecutionIntent calldata intent,
        bytes calldata signature
    ) external returns (address signer) {
        if (block.timestamp > intent.deadline) {
            revert AuthorizationExpired();
        }

        if (usedNonces[intent.agent][intent.nonce]) {
            revert NonceAlreadyUsed();
        }

        bytes32 digest = hashIntent(intent);

        signer = digest.recover(signature);

        if (signer != intent.agent) {
            revert InvalidSigner();
        }

        usedNonces[intent.agent][intent.nonce] = true;
    }
}

contract PhaseP6EIP712Test is Test {
    ExecutionAuthorizationHarness internal auth;

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

    function setUp() public {
        auth = new ExecutionAuthorizationHarness();

        agent = vm.addr(agentPrivateKey);
        attacker = vm.addr(attackerPrivateKey);
    }

    function _intent(
        uint256 nonce,
        uint256 deadline
    )
        internal
        view
        returns (
            ExecutionAuthorizationHarness.ExecutionIntent memory
        )
    {
        return ExecutionAuthorizationHarness.ExecutionIntent({
            operator: OPERATOR,
            agent: agent,
            target: TARGET,
            selector: bytes4(keccak256("execute(uint256)")),
            calldataHash: keccak256(
                abi.encodeWithSignature(
                    "execute(uint256)",
                    1 ether
                )
            ),
            amount: 1 ether,
            value: 0,
            proofModuleKey: PROOF_DOMAIN,
            proofId: 1,
            nonce: nonce,
            deadline: deadline
        });
    }

    function _sign(
        ExecutionAuthorizationHarness.ExecutionIntent memory intent,
        uint256 privateKey
    )
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 digest = auth.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(privateKey, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_EIP712_DigestIsDeterministic() public view {
        ExecutionAuthorizationHarness.ExecutionIntent memory a =
            _intent(1, block.timestamp + 1 hours);

        ExecutionAuthorizationHarness.ExecutionIntent memory b =
            _intent(1, block.timestamp + 1 hours);

        assertEq(
            auth.hashIntent(a),
            auth.hashIntent(b)
        );
    }

    function test_ValidAgentSignatureIsAccepted() public {
        ExecutionAuthorizationHarness.ExecutionIntent memory intent =
            _intent(1, block.timestamp + 1 hours);

        bytes memory signature = _sign(
            intent,
            agentPrivateKey
        );

        address recovered =
            auth.verifyAndConsume(
                intent,
                signature
            );

        assertEq(
            recovered,
            agent
        );

        assertTrue(
            auth.usedNonces(agent, 1)
        );
    }

    function test_AttackerSignatureIsRejected() public {
        ExecutionAuthorizationHarness.ExecutionIntent memory intent =
            _intent(1, block.timestamp + 1 hours);

        bytes memory signature = _sign(
            intent,
            attackerPrivateKey
        );

        vm.expectRevert(
            ExecutionAuthorizationHarness.InvalidSigner.selector
        );

        auth.verifyAndConsume(
            intent,
            signature
        );
    }

    function test_ReplayIsRejected() public {
        ExecutionAuthorizationHarness.ExecutionIntent memory intent =
            _intent(1, block.timestamp + 1 hours);

        bytes memory signature = _sign(
            intent,
            agentPrivateKey
        );

        auth.verifyAndConsume(
            intent,
            signature
        );

        vm.expectRevert(
            ExecutionAuthorizationHarness.NonceAlreadyUsed.selector
        );

        auth.verifyAndConsume(
            intent,
            signature
        );
    }

    function test_DifferentNonceCreatesIndependentAuthorization()
        public
    {
        ExecutionAuthorizationHarness.ExecutionIntent memory first =
            _intent(1, block.timestamp + 1 hours);

        ExecutionAuthorizationHarness.ExecutionIntent memory second =
            _intent(2, block.timestamp + 1 hours);

        assertTrue(
            auth.hashIntent(first) != auth.hashIntent(second)
        );
    }

    function test_ExpiredAuthorizationIsRejected() public {
        ExecutionAuthorizationHarness.ExecutionIntent memory intent =
            _intent(
                1,
                block.timestamp + 1 hours
            );

        bytes memory signature = _sign(
            intent,
            agentPrivateKey
        );

        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert(
            ExecutionAuthorizationHarness.AuthorizationExpired.selector
        );

        auth.verifyAndConsume(
            intent,
            signature
        );
    }

    function test_TargetMutationInvalidatesSignature() public {
        ExecutionAuthorizationHarness.ExecutionIntent memory intent =
            _intent(1, block.timestamp + 1 hours);

        bytes memory signature = _sign(
            intent,
            agentPrivateKey
        );

        intent.target =
            address(0x9999);

        vm.expectRevert(
            ExecutionAuthorizationHarness.InvalidSigner.selector
        );

        auth.verifyAndConsume(
            intent,
            signature
        );
    }

    function test_AmountMutationInvalidatesSignature() public {
        ExecutionAuthorizationHarness.ExecutionIntent memory intent =
            _intent(1, block.timestamp + 1 hours);

        bytes memory signature = _sign(
            intent,
            agentPrivateKey
        );

        intent.amount =
            100 ether;

        vm.expectRevert(
            ExecutionAuthorizationHarness.InvalidSigner.selector
        );

        auth.verifyAndConsume(
            intent,
            signature
        );
    }

    function test_CalldataMutationInvalidatesSignature() public {
        ExecutionAuthorizationHarness.ExecutionIntent memory intent =
            _intent(1, block.timestamp + 1 hours);

        bytes memory signature = _sign(
            intent,
            agentPrivateKey
        );

        intent.calldataHash =
            keccak256(
                abi.encodeWithSignature(
                    "execute(uint256)",
                    100 ether
                )
            );

        vm.expectRevert(
            ExecutionAuthorizationHarness.InvalidSigner.selector
        );

        auth.verifyAndConsume(
            intent,
            signature
        );
    }

    function test_OperatorMutationInvalidatesSignature() public {
        ExecutionAuthorizationHarness.ExecutionIntent memory intent =
            _intent(1, block.timestamp + 1 hours);

        bytes memory signature = _sign(
            intent,
            agentPrivateKey
        );

        intent.operator =
            address(0x9999);

        vm.expectRevert(
            ExecutionAuthorizationHarness.InvalidSigner.selector
        );

        auth.verifyAndConsume(
            intent,
            signature
        );
    }

    function test_ProofDomainMutationInvalidatesSignature() public {
        ExecutionAuthorizationHarness.ExecutionIntent memory intent =
            _intent(1, block.timestamp + 1 hours);

        bytes memory signature = _sign(
            intent,
            agentPrivateKey
        );

        intent.proofModuleKey =
            keccak256("different.domain");

        vm.expectRevert(
            ExecutionAuthorizationHarness.InvalidSigner.selector
        );

        auth.verifyAndConsume(
            intent,
            signature
        );
    }
}
