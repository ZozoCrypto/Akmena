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

    function invariant_protocolVersionConstant() public view {
        assertEq(core.PROTOCOL_VERSION(), "2.0.0");
    }

    function invariant_deployerNeverChanges() public view {
        assertEq(core.deployer(), DEPLOYER);
    }

    function invariant_getModuleNeverReturnsEnabledZeroAddress() public view {
        uint256 length = handler.registeredKeysLength();
        for (uint256 i = 0; i < length; ++i) {
            bytes32 k = handler.registeredKeys(i);
            (address moduleAddress, bool isEnabled, string memory version) = core.getModule(k);

            if (isEnabled) {
                assertTrue(moduleAddress != address(0));
            }
        }
    }
}
