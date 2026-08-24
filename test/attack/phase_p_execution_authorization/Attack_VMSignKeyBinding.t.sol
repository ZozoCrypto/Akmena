// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Attack_VMSignKeyBindingTest is Test {
    using ECDSA for bytes32;

    uint256 internal constant AGENT_KEY = 0xA11CE;
    uint256 internal constant SECOND_AGENT_KEY = 0xBEEF;

    function test_DirectVmSignUsesRequestedKey()
        public
    {
        bytes32 digest =
            keccak256("Akmena P-7E.3.4");

        address agent =
            vm.addr(AGENT_KEY);

        address secondAgent =
            vm.addr(SECOND_AGENT_KEY);

        assertTrue(
            agent != secondAgent,
            "test keys unexpectedly resolve to same address"
        );

        (
            uint8 v1,
            bytes32 r1,
            bytes32 s1
        ) =
            vm.sign(
                AGENT_KEY,
                digest
            );

        (
            uint8 v2,
            bytes32 r2,
            bytes32 s2
        ) =
            vm.sign(
                SECOND_AGENT_KEY,
                digest
            );

        bytes memory sig1 =
            abi.encodePacked(
                r1,
                s1,
                v1
            );

        bytes memory sig2 =
            abi.encodePacked(
                r2,
                s2,
                v2
            );

        address recovered1 =
            digest.recover(sig1);

        address recovered2 =
            digest.recover(sig2);

        emit log_named_address(
            "AGENT",
            agent
        );

        emit log_named_address(
            "SECOND_AGENT",
            secondAgent
        );

        emit log_named_address(
            "RECOVERED_1",
            recovered1
        );

        emit log_named_address(
            "RECOVERED_2",
            recovered2
        );

        assertEq(
            recovered1,
            agent,
            "first vm.sign did not use AGENT_KEY"
        );

        assertEq(
            recovered2,
            secondAgent,
            "second vm.sign did not use SECOND_AGENT_KEY"
        );

        assertTrue(
            keccak256(sig1) !=
            keccak256(sig2),
            "signatures unexpectedly identical"
        );
    }

    function test_DifferentKeysProduceDifferentAddresses()
        public
    {
        address agent =
            vm.addr(AGENT_KEY);

        address secondAgent =
            vm.addr(SECOND_AGENT_KEY);

        assertTrue(
            agent != secondAgent
        );
    }
}
