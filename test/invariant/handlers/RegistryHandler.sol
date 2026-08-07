// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Registry} from "../../../src/registry/Registry.sol";

contract RegistryHandler {
    Registry public registry;

    constructor(Registry _registry) {
        registry = _registry;
    }

    function allocateIdentity() external {
        try registry.allocateIdentityId() returns (uint256) {} catch {}
    }
}
