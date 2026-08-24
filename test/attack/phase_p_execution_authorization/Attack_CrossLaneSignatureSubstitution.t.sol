// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract CrossLaneSignatureHarness is EIP712 {
    using ECDSA for bytes32;

    bytes32 internal constant TYPEHASH =
        keccak256(
            "Authorization(address agent,bytes32 lane,uint256 nonce,uint256 deadline)"
        );

    struct Authorization {
        address agent;
        bytes32 lane;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(
        address =>
        mapping(bytes32 =>
        mapping(uint256 => bool))
    )
    public used;

    error InvalidSigner();
    error Replay();
    error Expired();

    constructor()
        EIP712(
            "AkmenaCrossLane",
            "1"
        )
    {}

    function hashAuthorization(
        Authorization memory authorization
    )
        public
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    TYPEHASH,
                    authorization.agent,
                    authorization.lane,
                    authorization.nonce,
                    authorization.deadline
                )
            )
        );
    }

    function execute(
        Authorization calldata authorization,
        bytes calldata signature
    )
        external
    {
        if (
            block.timestamp >
            authorization.deadline
        ) {
            revert Expired();
        }

        if (
            used[
                authorization.agent
            ][
                authorization.lane
            ][
                authorization.nonce
            ]
        ) {
            revert Replay();
        }

        address signer =
            hashAuthorization(
                authorization
            ).recover(
                signature
            );

        if (
            signer !=
            authorization.agent
        ) {
            revert InvalidSigner();
        }

        used[
            authorization.agent
        ][
            authorization.lane
        ][
            authorization.nonce
        ] = true;
    }
}

contract Attack_CrossLaneSignatureSubstitutionTest is Test {

    CrossLaneSignatureHarness internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    bytes32 internal constant PAYMENT_LANE =
        keccak256(
            "akmena.lane.payment"
        );

    bytes32 internal constant ESCROW_LANE =
        keccak256(
            "akmena.lane.escrow"
        );

    function setUp()
        public
    {
        auth =
            new CrossLaneSignatureHarness();

        agent =
            vm.addr(
                AGENT_KEY
            );
    }

    function _authorization(
        bytes32 lane,
        uint256 nonce
    )
        internal
        view
        returns (
            CrossLaneSignatureHarness.Authorization memory
        )
    {
        return
            CrossLaneSignatureHarness.Authorization({
                agent: agent,
                lane: lane,
                nonce: nonce,
                deadline:
                    block.timestamp + 1 hours
            });
    }

    function _sign(
        CrossLaneSignatureHarness.Authorization memory authorization
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            auth.hashAuthorization(
                authorization
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

    function test_PaymentSignatureCannotExecuteEscrow()
        public
    {
        CrossLaneSignatureHarness.Authorization memory payment =
            _authorization(
                PAYMENT_LANE,
                1
            );

        bytes memory signature =
            _sign(payment);

        CrossLaneSignatureHarness.Authorization memory escrow =
            CrossLaneSignatureHarness.Authorization({
                agent: payment.agent,
                lane: ESCROW_LANE,
                nonce: payment.nonce,
                deadline: payment.deadline
            });

        vm.expectRevert(
            CrossLaneSignatureHarness.InvalidSigner.selector
        );

        auth.execute(
            escrow,
            signature
        );
    }

    function test_EscrowSignatureCannotExecutePayment()
        public
    {
        CrossLaneSignatureHarness.Authorization memory escrow =
            _authorization(
                ESCROW_LANE,
                1
            );

        bytes memory signature =
            _sign(escrow);

        CrossLaneSignatureHarness.Authorization memory payment =
            CrossLaneSignatureHarness.Authorization({
                agent: escrow.agent,
                lane: PAYMENT_LANE,
                nonce: escrow.nonce,
                deadline: escrow.deadline
            });

        vm.expectRevert(
            CrossLaneSignatureHarness.InvalidSigner.selector
        );

        auth.execute(
            payment,
            signature
        );
    }

    function test_PaymentAuthorizationExecutes()
        public
    {
        CrossLaneSignatureHarness.Authorization memory payment =
            _authorization(
                PAYMENT_LANE,
                1
            );

        auth.execute(
            payment,
            _sign(payment)
        );

        assertTrue(
            auth.used(
                agent,
                PAYMENT_LANE,
                1
            )
        );
    }

    function test_EscrowAuthorizationExecutes()
        public
    {
        CrossLaneSignatureHarness.Authorization memory escrow =
            _authorization(
                ESCROW_LANE,
                1
            );

        auth.execute(
            escrow,
            _sign(escrow)
        );

        assertTrue(
            auth.used(
                agent,
                ESCROW_LANE,
                1
            )
        );
    }
}
