// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract DirectStateHarness is EIP712 {
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
        EIP712("AkmenaDirectState", "1")
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
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    TYPEHASH,
                    intent.agent,
                    intent.lane,
                    intent.nonce,
                    intent.deadline
                )
            )
        );
    }

    function execute(
        Intent calldata intent,
        bytes calldata signature
    ) external returns (bool) {

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

        return true;
    }

    function cancel(
        Intent calldata intent,
        bytes calldata signature
    ) external returns (bool) {

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

        return true;
    }
}

contract Attack_DirectStateAssertionTest is Test {

    DirectStateHarness internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    bytes32 internal constant LANE =
        keccak256("payment");

    function setUp() public {
        auth = new DirectStateHarness();
        agent = vm.addr(AGENT_KEY);
    }

    function _intent(uint256 nonce)
        internal
        view
        returns (DirectStateHarness.Intent memory)
    {
        return DirectStateHarness.Intent({
            agent: agent,
            lane: LANE,
            nonce: nonce,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(
        DirectStateHarness.Intent memory intent
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            auth.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(AGENT_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_DirectExecuteState()
        public
    {
        DirectStateHarness.Intent memory intent =
            _intent(1);

        bytes memory signature =
            _sign(intent);

        bool first =
            auth.execute(
                intent,
                signature
            );

        assertTrue(first);
        assertTrue(
            auth.used(agent, LANE, 1),
            "used must be true after execution"
        );

        /*
         * LOW-LEVEL CALL:
         *
         * We intentionally bypass vm.expectRevert.
         * This tells us exactly whether the EVM call itself reverts.
         */
        (bool success, bytes memory returndata) =
            address(auth).call(
                abi.encodeCall(
                    DirectStateHarness.execute,
                    (intent, signature)
                )
            );

        assertFalse(
            success,
            "CRITICAL: second execution actually succeeded"
        );

        assertEq(
            bytes4(returndata),
            DirectStateHarness.Replay.selector,
            "unexpected revert reason"
        );
    }

    function test_DirectCancelState()
        public
    {
        DirectStateHarness.Intent memory intent =
            _intent(1);

        bytes memory signature =
            _sign(intent);

        bool first =
            auth.cancel(
                intent,
                signature
            );

        assertTrue(first);
        assertTrue(
            auth.cancelled(agent, LANE, 1),
            "cancelled must be true"
        );

        (bool success, bytes memory returndata) =
            address(auth).call(
                abi.encodeCall(
                    DirectStateHarness.execute,
                    (intent, signature)
                )
            );

        assertFalse(
            success,
            "CRITICAL: cancelled authorization executed"
        );

        assertEq(
            bytes4(returndata),
            DirectStateHarness.Cancelled.selector,
            "unexpected revert reason"
        );
    }

    function test_StateCannotChangeAcrossRead()
        public
    {
        DirectStateHarness.Intent memory intent =
            _intent(1);

        bytes memory signature =
            _sign(intent);

        auth.execute(
            intent,
            signature
        );

        bool before =
            auth.used(agent, LANE, 1);

        bytes32 digest =
            auth.hashIntent(intent);

        bool afterRead =
            auth.used(agent, LANE, 1);

        assertTrue(before);
        assertTrue(afterRead);
        assertEq(
            digest,
            auth.hashIntent(intent)
        );
    }
}
