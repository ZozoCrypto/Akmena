// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SettlementEngine} from "../../../src/economics/SettlementEngine.sol";
import {LibStorage} from "../../../src/storage/LibStorage.sol";

contract Attack_SettlementFabricationTest is Test {
    SettlementEngine internal settlement;

    address internal attacker = address(0xBEEF);
    address internal victim = address(0xCAFE);

    function setUp() public {
        settlement = new SettlementEngine();
    }

    function test_Attack_AnyoneCanFabricateSettlement() public {
        bytes32 settlementId = keccak256("forged-settlement");

        vm.prank(attacker);

        settlement.recordSettlement(settlementId, victim, attacker, 1_000_000 ether);

        LibStorage.SettlementData memory data = settlement.getSettlement(settlementId);

        assertEq(data.payer, victim);
        assertEq(data.payee, attacker);
        assertEq(data.amount, 1_000_000 ether);
        assertGt(data.timestamp, 0);
    }

    function test_Attack_AttackerCanChooseVictimAsPayer() public {
        bytes32 settlementId = keccak256("victim-payer");

        vm.prank(attacker);

        settlement.recordSettlement(settlementId, victim, attacker, 500 ether);

        LibStorage.SettlementData memory data = settlement.getSettlement(settlementId);

        assertEq(data.payer, victim);
        assertEq(data.payee, attacker);
        assertEq(data.amount, 500 ether);
    }

    function test_Attack_SettlementRequiresNoEconomicProof() public {
        bytes32 settlementId = keccak256("zero-context-settlement");

        vm.prank(attacker);

        settlement.recordSettlement(settlementId, victim, attacker, 1 ether);

        assertTrue(settlement.exists(settlementId));
    }
}
