// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CapabilityEngine} from "../../src/authorization/CapabilityEngine.sol";
import {ICapabilityEngine} from "../../src/authorization/ICapabilityEngine.sol";

contract CapabilityEngineTest is Test {
    CapabilityEngine public engine;
    address public identity = address(0x123);
    bytes32 public constant EXECUTE_CAPABILITY = keccak256("EXECUTE_ACTION");

    function setUp() public {
        engine = new CapabilityEngine();
    }

    function test_GrantCapability() public {
        vm.expectEmit(true, true, true, true);
        emit ICapabilityEngine.CapabilityGranted(identity, EXECUTE_CAPABILITY);

        engine.grantCapability(identity, EXECUTE_CAPABILITY);
        assertTrue(engine.hasCapability(identity, EXECUTE_CAPABILITY), "Capability should be granted");
    }

    function test_RevertWhen_GrantingCapabilityTwice() public {
        engine.grantCapability(identity, EXECUTE_CAPABILITY);

        vm.expectRevert(ICapabilityEngine.CapabilityAlreadyGranted.selector);
        engine.grantCapability(identity, EXECUTE_CAPABILITY);
    }

    function test_RevokeCapability() public {
        engine.grantCapability(identity, EXECUTE_CAPABILITY);

        vm.expectEmit(true, true, true, true);
        emit ICapabilityEngine.CapabilityRevoked(identity, EXECUTE_CAPABILITY);

        engine.revokeCapability(identity, EXECUTE_CAPABILITY);
        assertFalse(engine.hasCapability(identity, EXECUTE_CAPABILITY), "Capability should be revoked");
    }

    function test_RevertWhen_RevokingNonExistentCapability() public {
        vm.expectRevert(ICapabilityEngine.CapabilityNotFound.selector);
        engine.revokeCapability(identity, EXECUTE_CAPABILITY);
    }

    function test_RevertWhen_UsingZeroAddress() public {
        vm.expectRevert(ICapabilityEngine.InvalidIdentityAddress.selector);
        engine.grantCapability(address(0), EXECUTE_CAPABILITY);

        vm.expectRevert(ICapabilityEngine.InvalidIdentityAddress.selector);
        engine.revokeCapability(address(0), EXECUTE_CAPABILITY);
    }
}
