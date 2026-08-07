// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import {Registry} from "../../src/registry/Registry.sol";
import {RegistryHandler} from "./handlers/RegistryHandler.sol";

contract RegistryInvariant is StdInvariant, Test {

    Registry registry;
    RegistryHandler handler;

    function setUp() public {

        registry = new Registry();

        handler = new RegistryHandler(registry);

        targetContract(address(handler));
    }

    /// Identity IDs must never move backwards.
    function invariant_identityCounterMonotonic() public view {

        assertGe(
            registry.nextIdentityId(),
            1
        );
    }

    /// Identity ID zero must remain permanently reserved.
    function invariant_identityZeroReserved() public view {

        assertEq(
            registry.identityAddress(0),
            address(0)
        );

        assertEq(
            registry.exists(0),
            false
        );
    }
}
