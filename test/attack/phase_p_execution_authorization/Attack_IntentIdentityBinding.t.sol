// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract IntentIdentityHarness is EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant TYPEHASH =
        keccak256(
            "Intent(address agent,address operator,address target,bytes4 selector,uint256 value,bytes32 dataHash,uint256 nonce,uint256 deadline,bytes32 domain)"
        );

    error InvalidSigner();

    constructor()
        EIP712(
            "AkmenaIntentIdentity",
            "1"
        )
    {}

    struct Intent {
        address agent;
        address operator;
        address target;
        bytes4 selector;
        uint256 value;
        bytes32 dataHash;
        uint256 nonce;
        uint256 deadline;
        bytes32 domain;
    }

    function hashIntent(
        Intent memory intent
    )
        public
        view
        returns(bytes32)
    {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    TYPEHASH,
                    intent.agent,
                    intent.operator,
                    intent.target,
                    intent.selector,
                    intent.value,
                    intent.dataHash,
                    intent.nonce,
                    intent.deadline,
                    intent.domain
                )
            )
        );
    }

    function verify(
        Intent calldata intent,
        bytes calldata sig
    )
        external
        view
        returns(address)
    {
        address signer =
            hashIntent(intent).recover(sig);

        if (signer != intent.agent) {
            revert InvalidSigner();
        }

        return signer;
    }
}


contract Attack_IntentIdentityBindingTest is Test {

    IntentIdentityHarness internal auth;

    uint256 constant AGENT_KEY =
        0xA11CE;

    address agent;

    function setUp() public {
        auth =
            new IntentIdentityHarness();

        agent =
            vm.addr(AGENT_KEY);
    }

    function _intent()
        internal
        view
        returns(IntentIdentityHarness.Intent memory)
    {
        return IntentIdentityHarness.Intent({
            agent: agent,
            operator: address(0x1111),
            target: address(0x2222),
            selector: bytes4(keccak256("pay()")),
            value: 1 ether,
            dataHash: keccak256("PAY"),
            nonce: 1,
            deadline: block.timestamp + 1 hours,
            domain: keccak256("payment")
        });
    }

    function test_TargetMutationChangesIdentity()
        public
        view
    {
        autoCheck(_intent());
    }

    function autoCheck(
        IntentIdentityHarness.Intent memory intent
    )
        internal
        view
    {
        bytes32 original =
            auth.hashIntent(intent);

        intent.target =
            address(0x9999);

        assertTrue(
            original != auth.hashIntent(intent)
        );
    }

    function test_SelectorMutationChangesIdentity()
        public
        view
    {
        IntentIdentityHarness.Intent memory intent =
            _intent();

        bytes32 original =
            auth.hashIntent(intent);

        intent.selector =
            bytes4(
                keccak256("withdraw()")
            );

        assertTrue(
            original != auth.hashIntent(intent),
            "selector mutation must change identity"
        );
    }


    function test_DataMutationChangesIdentity()
        public
        view
    {
        IntentIdentityHarness.Intent memory intent =
            _intent();

        bytes32 original =
            auth.hashIntent(intent);

        intent.dataHash =
            keccak256(
                "ATTACKER_PAYLOAD"
            );

        assertTrue(
            original != auth.hashIntent(intent),
            "calldata mutation must change identity"
        );
    }


    function test_ValueMutationChangesIdentity()
        public
        view
    {
        IntentIdentityHarness.Intent memory intent =
            _intent();

        bytes32 original =
            auth.hashIntent(intent);

        intent.value =
            100 ether;

        assertTrue(
            original != auth.hashIntent(intent),
            "value mutation must change identity"
        );
    }


    function test_OperatorMutationChangesIdentity()
        public
        view
    {
        IntentIdentityHarness.Intent memory intent =
            _intent();

        bytes32 original =
            auth.hashIntent(intent);

        intent.operator =
            address(0x9999);

        assertTrue(
            original != auth.hashIntent(intent),
            "operator mutation must change identity"
        );
    }


    function test_DomainMutationChangesIdentity()
        public
        view
    {
        IntentIdentityHarness.Intent memory intent =
            _intent();

        bytes32 original =
            auth.hashIntent(intent);

        intent.domain =
            keccak256(
                "escrow"
            );

        assertTrue(
            original != auth.hashIntent(intent),
            "domain mutation must change identity"
        );
    }

}
