// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract IntentHashFuzzHarness is EIP712 {

    bytes32 constant TYPEHASH =
        keccak256(
            "Intent(address agent,address operator,address target,bytes4 selector,uint256 value,bytes32 dataHash,uint256 nonce,uint256 deadline,bytes32 domain)"
        );

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

    constructor()
        EIP712(
            "AkmenaIntentFuzz",
            "1"
        )
    {}

    function hashIntent(
        Intent memory i
    )
        public
        view
        returns(bytes32)
    {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    TYPEHASH,
                    i.agent,
                    i.operator,
                    i.target,
                    i.selector,
                    i.value,
                    i.dataHash,
                    i.nonce,
                    i.deadline,
                    i.domain
                )
            )
        );
    }
}


contract Attack_IntentHashFuzzTest is Test {

    IntentHashFuzzHarness internal auth;

    function setUp()
        public
    {
        auth =
            new IntentHashFuzzHarness();
    }


    function testFuzz_FieldMutationAlwaysChangesHash(
        address target,
        uint256 value,
        uint256 nonce,
        bytes32 domain
    )
        public
        view
    {
        IntentHashFuzzHarness.Intent memory base =
            IntentHashFuzzHarness.Intent({
                agent: address(0x1111),
                operator: address(0x2222),
                target: address(0x3333),
                selector: bytes4(keccak256("execute()")),
                value: 1 ether,
                dataHash: keccak256("DATA"),
                nonce: 1,
                deadline: 1000000,
                domain: keccak256("payment")
            });


        IntentHashFuzzHarness.Intent memory mutated =
            base;

        mutated.target = target;

        if (mutated.target != base.target) {
            assertTrue(
                auth.hashIntent(base)
                !=
                auth.hashIntent(mutated)
            );
        }

        mutated.value = value;

        if (mutated.value != base.value) {
            assertTrue(
                auth.hashIntent(base)
                !=
                auth.hashIntent(mutated)
            );
        }

        mutated.nonce = nonce;

        if (mutated.nonce != base.nonce) {
            assertTrue(
                auth.hashIntent(base)
                !=
                auth.hashIntent(mutated)
            );
        }

        mutated.domain = domain;

        if (mutated.domain != base.domain) {
            assertTrue(
                auth.hashIntent(base)
                !=
                auth.hashIntent(mutated)
            );
        }
    }
}
