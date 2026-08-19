// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PaymentsEngine} from "../../../src/economics/PaymentsEngine.sol";

contract Attack_PaymentsVolumeSpoofTest is Test {
    PaymentsEngine internal payments;

    address internal attacker = address(0xBEEF);
    address internal victim = address(0xCAFE);

    function setUp() public {
        payments = new PaymentsEngine();
    }

    function test_Attack_AnyoneCanFabricatePaymentVolume() public {
        vm.prank(attacker);

        payments.executePayment(victim, attacker, 1_000_000 ether);

        assertEq(payments.getTotalVolume(), 1_000_000 ether);
    }

    function test_Attack_AttackerCanSpamVolume() public {
        vm.startPrank(attacker);

        for (uint256 i = 0; i < 10; ++i) {
            payments.executePayment(victim, attacker, 1 ether);
        }

        vm.stopPrank();

        assertEq(payments.getTotalVolume(), 10 ether);
    }
}
