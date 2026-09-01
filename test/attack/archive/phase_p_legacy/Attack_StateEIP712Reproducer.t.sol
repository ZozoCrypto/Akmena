// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract StateEIP712Reproducer is EIP712 {
    using ECDSA for bytes32;

    bytes32 internal constant TYPEHASH =
        keccak256(
            "Execution(address agent,bytes32 lane,uint256 nonce,uint256 deadline)"
        );

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public used;

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public cancelled;

    error Replay();
    error Cancelled();
    error Expired();
    error InvalidSigner();

    constructor()
        EIP712("AkmenaStateReproducer", "1")
    {}

    struct Intent {
        address agent;
        bytes32 lane;
        uint256 nonce;
        uint256 deadline;
    }

    function hashIntent(
        Intent memory intent
    ) public view returns (bytes32) {
        bytes32 structHash =
            keccak256(
                abi.encode(
                    TYPEHASH,
                    intent.agent,
                    intent.lane,
                    intent.nonce,
                    intent.deadline
                )
            );

        return _hashTypedDataV4(structHash);
    }

    function execute(
        Intent calldata intent,
        bytes calldata signature
    ) external {
        if (block.timestamp > intent.deadline) {
            revert Expired();
        }

        if (cancelled[intent.agent][intent.lane][intent.nonce]) {
            revert Cancelled();
        }

        if (used[intent.agent][intent.lane][intent.nonce]) {
            revert Replay();
        }

        address signer =
            hashIntent(intent).recover(signature);

        if (signer != intent.agent) {
            revert InvalidSigner();
        }

        used[intent.agent][intent.lane][intent.nonce] = true;
    }

    function cancel(
        Intent calldata intent,
        bytes calldata signature
    ) external {
        if (block.timestamp > intent.deadline) {
            revert Expired();
        }

        if (cancelled[intent.agent][intent.lane][intent.nonce]) {
            revert Cancelled();
        }

        if (used[intent.agent][intent.lane][intent.nonce]) {
            revert Replay();
        }

        address signer =
            hashIntent(intent).recover(signature);

        if (signer != intent.agent) {
            revert InvalidSigner();
        }

        cancelled[intent.agent][intent.lane][intent.nonce] = true;
    }
}

contract Attack_StateEIP712ReproducerTest is Test {

    StateEIP712Reproducer internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    bytes32 internal constant LANE =
        keccak256("payment");

    function setUp() public {
        auth = new StateEIP712Reproducer();
        agent = vm.addr(AGENT_KEY);
    }

    function _intent(
        uint256 nonce
    )
        internal
        view
        returns (
            StateEIP712Reproducer.Intent memory
        )
    {
        return StateEIP712Reproducer.Intent({
            agent: agent,
            lane: LANE,
            nonce: nonce,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(
        StateEIP712Reproducer.Intent memory intent
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            auth.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(
                AGENT_KEY,
                digest
            );

        return abi.encodePacked(r, s, v);
    }

    function test_ExecuteConsumesNonce()
        public
    {
        StateEIP712Reproducer.Intent memory intent =
            _intent(1);

        auth.execute(
            intent,
            _sign(intent)
        );

        assertTrue(
            auth.used(
                agent,
                LANE,
                1
            )
        );

        vm.expectRevert(
            StateEIP712Reproducer.Replay.selector
        );

        auth.execute(
            intent,
            _sign(intent)
        );
    }

    function test_CancelBlocksExecution()
        public
    {
        StateEIP712Reproducer.Intent memory intent =
            _intent(1);

        auth.cancel(
            intent,
            _sign(intent)
        );

        assertTrue(
            auth.cancelled(
                agent,
                LANE,
                1
            )
        );

        vm.expectRevert(
            StateEIP712Reproducer.Cancelled.selector
        );

        auth.execute(
            intent,
            _sign(intent)
        );
    }

    function test_ExecuteBlocksCancellation()
        public
    {
        StateEIP712Reproducer.Intent memory intent =
            _intent(1);

        auth.execute(
            intent,
            _sign(intent)
        );

        assertTrue(
            auth.used(
                agent,
                LANE,
                1
            )
        );

        vm.expectRevert(
            StateEIP712Reproducer.Replay.selector
        );

        auth.cancel(
            intent,
            _sign(intent)
        );
    }

    function test_ExpiredAuthorizationDoesNotConsumeNonce()
        public
    {
        StateEIP712Reproducer.Intent memory intent =
            _intent(1);

        bytes memory signature =
            _sign(intent);

        vm.warp(
            intent.deadline + 1
        );

        vm.expectRevert(
            StateEIP712Reproducer.Expired.selector
        );

        auth.execute(
            intent,
            signature
        );

        assertFalse(
            auth.used(
                agent,
                LANE,
                1
            )
        );
    }
}
