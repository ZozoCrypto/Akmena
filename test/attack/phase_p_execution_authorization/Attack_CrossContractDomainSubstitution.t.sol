// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract DomainAuthorizationHarness is EIP712 {
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

    constructor(
        string memory name_
    )
        EIP712(
            name_,
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

contract Attack_CrossContractDomainSubstitutionTest is Test {

    DomainAuthorizationHarness internal domainA;
    DomainAuthorizationHarness internal domainB;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    bytes32 internal constant PAYMENT_LANE =
        keccak256(
            "akmena.lane.payment"
        );

    function setUp()
        public
    {
        domainA =
            new DomainAuthorizationHarness(
                "AkmenaPayment"
            );

        domainB =
            new DomainAuthorizationHarness(
                "AkmenaEscrow"
            );

        agent =
            vm.addr(
                AGENT_KEY
            );
    }

    function _authorization(
        uint256 nonce
    )
        internal
        view
        returns (
            DomainAuthorizationHarness.Authorization memory
        )
    {
        return
            DomainAuthorizationHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: nonce,
                deadline:
                    block.timestamp + 1 hours
            });
    }

    function _signA(
        DomainAuthorizationHarness.Authorization memory authorization
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            domainA.hashAuthorization(
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

    function _signB(
        DomainAuthorizationHarness.Authorization memory authorization
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            domainB.hashAuthorization(
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

    function test_DomainAHashDiffersFromDomainB()
        public
    {
        DomainAuthorizationHarness.Authorization memory authorization =
            _authorization(1);

        assertTrue(
            domainA.hashAuthorization(
                authorization
            ) !=
            domainB.hashAuthorization(
                authorization
            ),
            "CRITICAL: EIP-712 domains are identical"
        );
    }

    function test_DomainASignatureCannotExecuteDomainB()
        public
    {
        DomainAuthorizationHarness.Authorization memory authorization =
            _authorization(1);

        bytes memory signature =
            _signA(
                authorization
            );

        vm.expectRevert(
            DomainAuthorizationHarness.InvalidSigner.selector
        );

        domainB.execute(
            authorization,
            signature
        );
    }

    function test_DomainBSignatureCannotExecuteDomainA()
        public
    {
        DomainAuthorizationHarness.Authorization memory authorization =
            _authorization(1);

        bytes memory signature =
            _signB(
                authorization
            );

        vm.expectRevert(
            DomainAuthorizationHarness.InvalidSigner.selector
        );

        domainA.execute(
            authorization,
            signature
        );
    }

    function test_DomainASignatureExecutesOnA()
        public
    {
        DomainAuthorizationHarness.Authorization memory authorization =
            _authorization(1);

        domainA.execute(
            authorization,
            _signA(authorization)
        );

        assertTrue(
            domainA.used(
                agent,
                PAYMENT_LANE,
                1
            )
        );
    }

    function test_DomainBSignatureExecutesOnB()
        public
    {
        DomainAuthorizationHarness.Authorization memory authorization =
            _authorization(1);

        domainB.execute(
            authorization,
            _signB(authorization)
        );

        assertTrue(
            domainB.used(
                agent,
                PAYMENT_LANE,
                1
            )
        );
    }
}
