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
        registry.bindIdentityFactory(address(handler));

        targetContract(address(handler));
    }

    /// Every successful allocation advances the counter exactly once.
    function invariant_identityCounterMatchesSuccessfulAllocations() public view {
        assertEq(registry.nextIdentityId(), handler.allocationCount() + 1);
    }

    /// The most recently allocated ID is exactly one below nextIdentityId.
    function invariant_lastAllocatedIdIsImmediatelyBeforeNext() public view {
        if (handler.allocationCount() == 0) {
            assertEq(handler.lastAllocatedId(), 0);
            assertEq(registry.nextIdentityId(), 1);
        } else {
            assertEq(handler.lastAllocatedId() + 1, registry.nextIdentityId());
        }
    }

    /// Identity ID zero remains permanently reserved.
    function invariant_identityZeroReserved() public view {
        assertEq(registry.identityAddress(0), address(0));
        assertFalse(registry.exists(0));
    }
}
