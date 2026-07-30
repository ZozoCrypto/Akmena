// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PaymentsEngine} from "../../src/economics/PaymentsEngine.sol";
import {IPaymentsEngine} from "../../src/economics/IPaymentsEngine.sol";

contract PaymentsEngineTest is Test {
    PaymentsEngine public engine;
    address public alice = address(0xA);
    address public bob = address(0xB);

    function setUp() public {
        engine = new PaymentsEngine();
    }

    function test_ExecutePayment() public {
        vm.expectEmit(true, true, true, true);
        emit IPaymentsEngine.PaymentExecuted(alice, bob, 100);

        engine.executePayment(alice, bob, 100);
        assertEq(engine.getTotalVolume(), 100);
    }

    function test_MultiplePaymentsIncreaseVolume() public {
        engine.executePayment(alice, bob, 100);
        engine.executePayment(bob, alice, 250);
        
        assertEq(engine.getTotalVolume(), 350);
    }

    function test_RevertWhen_ZeroAmount() public {
        vm.expectRevert(IPaymentsEngine.InvalidAmount.selector);
        engine.executePayment(alice, bob, 0);
    }

    function test_RevertWhen_ZeroAddress() public {
        vm.expectRevert(IPaymentsEngine.InvalidAddress.selector);
        engine.executePayment(address(0), bob, 100);
    }
}
