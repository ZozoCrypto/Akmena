// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {CoreRouterHandler} from "./handlers/CoreRouterHandler.sol";

contract CoreRouterInvariant is StdInvariant, Test {

    AkmenaCore internal core;
    CoreRouterHandler internal handler;

    address internal immutable DEPLOYER = address(this);

    function setUp() public {

        core = new AkmenaCore();

        handler = new CoreRouterHandler(core);

        targetContract(address(handler));
    }

    /// -----------------------------------------------------------------------
    /// Core invariants
    /// -----------------------------------------------------------------------

    function invariant_protocolVersionConstant() public view {
        assertEq(core.PROTOCOL_VERSION(), "2.0.0");
    }

    function invariant_deployerNeverChanges() public view {
        assertEq(core.deployer(), DEPLOYER);
    }

    function invariant_getModuleNeverReturnsEnabledZeroAddress(bytes32 key)
        public
        view
    {
        (
            address module,
            bool enabled,

        ) = core.getModule(key);

        if (enabled) {
            assertTrue(module != address(0));
        }
    }
}
