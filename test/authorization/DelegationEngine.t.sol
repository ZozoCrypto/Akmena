// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DelegationEngine} from "../../src/authorization/DelegationEngine.sol";
import {IDelegationEngine} from "../../src/authorization/IDelegationEngine.sol";

contract DelegationEngineTest is Test {
    DelegationEngine public engine;
    address public identity = address(0x111);
    address public delegate = address(0x222);

    function setUp() public {
        engine = new DelegationEngine();
    }

    function test_SetDelegate() public {
        vm.prank(identity);
        vm.expectEmit(true, true, true, true);
        emit IDelegationEngine.DelegateSet(identity, delegate, true);

        engine.setDelegate(delegate, true);
        assertTrue(engine.isDelegate(identity, delegate), "Delegate should be active");
    }

    function test_RevokeDelegate() public {
        vm.startPrank(identity);
        engine.setDelegate(delegate, true);
        
        vm.expectEmit(true, true, true, true);
        emit IDelegationEngine.DelegateSet(identity, delegate, false);

        engine.setDelegate(delegate, false);
        vm.stopPrank();

        assertFalse(engine.isDelegate(identity, delegate), "Delegate should be revoked");
    }

    function test_RevertWhen_SettingZeroAddressDelegate() public {
        vm.prank(identity);
        vm.expectRevert(IDelegationEngine.InvalidAddress.selector);
        engine.setDelegate(address(0), true);
    }

    function test_ReturnsFalseForUnknownDelegate() public view {
        assertFalse(engine.isDelegate(identity, delegate), "Unknown delegate should return false");
    }
}
