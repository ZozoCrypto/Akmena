// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract DomainSeparatedAuthorization is EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant TYPEHASH =
        keccak256(
            "ExecutionIntent(address operator,address agent,address target,uint256 amount,uint256 nonce,uint256 deadline)"
        );

    struct ExecutionIntent {
        address operator;
        address agent;
        address target;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(address => mapping(uint256 => bool)) public used;

    error InvalidSigner();
    error Expired();
    error Replay();

    constructor()
        EIP712("AkmenaExecutionAuthorization", "1")
    {}

    function hashIntent(
        ExecutionIntent memory intent
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                TYPEHASH,
                intent.operator,
                intent.agent,
                intent.target,
                intent.amount,
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
            revert Expired();
        }

        if (used[intent.agent][intent.nonce]) {
            revert Replay();
        }

        signer = hashIntent(intent).recover(signature);

        if (signer != intent.agent) {
            revert InvalidSigner();
        }

        used[intent.agent][intent.nonce] = true;
    }
}

contract Attack_EIP712DomainSeparationTest is Test {
    DomainSeparatedAuthorization internal authA;
    DomainSeparatedAuthorization internal authB;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    address internal constant OPERATOR =
        address(0x1111);

    address internal constant TARGET =
        address(0x2222);

    function setUp() public {
        authA = new DomainSeparatedAuthorization();
        authB = new DomainSeparatedAuthorization();

        agent = vm.addr(AGENT_KEY);
    }

    function _intent(uint256 nonce)
        internal
        view
        returns (
            DomainSeparatedAuthorization.ExecutionIntent memory
        )
    {
        return DomainSeparatedAuthorization.ExecutionIntent({
            operator: OPERATOR,
            agent: agent,
            target: TARGET,
            amount: 1 ether,
            nonce: nonce,
            deadline: block.timestamp + 1 hours
        });
    }

    function _signA(
        DomainSeparatedAuthorization.ExecutionIntent memory intent
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = authA.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(AGENT_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_SameIntentSameDomainProducesSameDigest()
        public
        view
    {
        DomainSeparatedAuthorization.ExecutionIntent memory intent =
            _intent(1);

        assertEq(
            authA.hashIntent(intent),
            authA.hashIntent(intent)
        );
    }

    function test_DifferentVerifyingContractChangesDigest()
        public
        view
    {
        DomainSeparatedAuthorization.ExecutionIntent memory intent =
            _intent(1);

        assertTrue(
            authA.hashIntent(intent) !=
            authB.hashIntent(intent),
            "CRITICAL: verifying contract not bound to digest"
        );
    }

    function test_SignatureCannotCrossVerifyingContract()
        public
    {
        DomainSeparatedAuthorization.ExecutionIntent memory intent =
            _intent(1);

        bytes memory signature = _signA(intent);

        vm.expectRevert(
            DomainSeparatedAuthorization.InvalidSigner.selector
        );

        authB.verifyAndConsume(
            intent,
            signature
        );
    }

    function test_SignatureWorksOnOriginalContract()
        public
    {
        DomainSeparatedAuthorization.ExecutionIntent memory intent =
            _intent(1);

        bytes memory signature = _signA(intent);

        address recovered =
            authA.verifyAndConsume(
                intent,
                signature
            );

        assertEq(
            recovered,
            agent
        );
    }

    function test_ChainIdChangesDomainDigest()
        public
    {
        DomainSeparatedAuthorization.ExecutionIntent memory intent =
            _intent(1);

        bytes32 beforeChainChange =
            authA.hashIntent(intent);

        vm.chainId(8453);

        bytes32 afterChainChange =
            authA.hashIntent(intent);

        assertTrue(
            beforeChainChange != afterChainChange,
            "CRITICAL: chainId not bound to EIP-712 domain"
        );
    }

    function test_ChainIdMutationInvalidatesExistingSignature()
        public
    {
        DomainSeparatedAuthorization.ExecutionIntent memory intent =
            _intent(1);

        bytes memory signature = _signA(intent);

        vm.chainId(8453);

        vm.expectRevert(
            DomainSeparatedAuthorization.InvalidSigner.selector
        );

        authA.verifyAndConsume(
            intent,
            signature
        );
    }

    function test_DifferentNonceStillProducesDifferentDigest()
        public
        view
    {
        DomainSeparatedAuthorization.ExecutionIntent memory a =
            _intent(1);

        DomainSeparatedAuthorization.ExecutionIntent memory b =
            _intent(2);

        assertTrue(
            authA.hashIntent(a) != authA.hashIntent(b)
        );
    }

    function test_DifferentTargetStillProducesDifferentDigest()
        public
        view
    {
        DomainSeparatedAuthorization.ExecutionIntent memory a =
            _intent(1);

        DomainSeparatedAuthorization.ExecutionIntent memory b =
            _intent(1);

        b.target = address(0x9999);

        assertTrue(
            authA.hashIntent(a) != authA.hashIntent(b)
        );
    }
}
