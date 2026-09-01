// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";
import {TreasuryEngine} from "../../src/economics/TreasuryEngine.sol";
import {SettlementEngine} from "../../src/economics/SettlementEngine.sol";
import {PaymentsEngine} from "../../src/economics/PaymentsEngine.sol";

contract EconomicTruthInvariantTest is Test {
    TreasuryEngine internal treasury;
    SettlementEngine internal settlement;
    PaymentsEngine internal payments;
    AkmenaToken internal token;

    address internal attacker = address(0xBEEF);
    address internal victim = address(0xCAFE);

    function setUp() public {
        token = new AkmenaToken(attacker);

        treasury = new TreasuryEngine(
            address(token),
            attacker
        );

        settlement = new SettlementEngine();
        payments = new PaymentsEngine();
    }

    function test_TreasuryBookkeepingIsNotNativeCustody() public {
        uint256 beforeBalance = address(treasury).balance;

        vm.prank(attacker);
        token.approve(
            address(treasury),
            100 ether
        );

        vm.prank(attacker);
        treasury.fundTreasury(100 ether);

        uint256 afterBalance = address(treasury).balance;

        assertEq(
            beforeBalance,
            afterBalance,
            "Current TreasuryEngine unexpectedly moved native value"
        );
    }

    function test_SettlementRecordDoesNotMoveNativeValue() public {
        uint256 payerBefore = victim.balance;
        uint256 payeeBefore = attacker.balance;

        vm.prank(attacker);
        settlement.recordSettlement(
            keccak256("truth-test"),
            victim,
            attacker,
            1 ether
        );

        assertEq(victim.balance, payerBefore);
        assertEq(attacker.balance, payeeBefore);
    }

    function test_PaymentRecordDoesNotMoveNativeValue() public {
        uint256 before = attacker.balance;

        vm.prank(attacker);
        payments.executePayment(
            victim,
            attacker,
            1 ether
        );

        assertEq(
            attacker.balance,
            before,
            "PaymentsEngine currently does not move native value"
        );
    }
}
