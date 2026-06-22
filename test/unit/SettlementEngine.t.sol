// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/settlement/SettlementEngine.sol";
import "../../src/interfaces/ISettlementEngine.sol";

contract SettlementEngineTest is Test {
    SettlementEngine engine;

    bytes32 internal constant SETTLEMENT_ID = keccak256("settlement-1");

    bytes32 internal constant SETTLEMENT_ID_2 = keccak256("settlement-2");

    bytes32 internal constant ESCROW_ID = keccak256("escrow-1");

    address internal constant PAYER = address(0x1001);

    address internal constant PAYEE = address(0x2002);

    uint256 internal constant AMOUNT = 1 ether;

    function setUp() public {
        engine = new SettlementEngine();
    }

    function testRecordSettlement() public {
        engine.recordSettlement(SETTLEMENT_ID, ESCROW_ID, PAYER, PAYEE, AMOUNT);

        assertTrue(engine.exists(SETTLEMENT_ID));
    }

    function testCannotCreateDuplicateSettlement() public {
        engine.recordSettlement(SETTLEMENT_ID, ESCROW_ID, PAYER, PAYEE, AMOUNT);

        vm.expectRevert();

        engine.recordSettlement(SETTLEMENT_ID, ESCROW_ID, PAYER, PAYEE, AMOUNT);
    }

    function testCannotUseZeroPayer() public {
        vm.expectRevert();

        engine.recordSettlement(SETTLEMENT_ID, ESCROW_ID, address(0), PAYEE, AMOUNT);
    }

    function testCannotUseZeroPayee() public {
        vm.expectRevert();

        engine.recordSettlement(SETTLEMENT_ID, ESCROW_ID, PAYER, address(0), AMOUNT);
    }

    function testCannotUseZeroAmount() public {
        vm.expectRevert();

        engine.recordSettlement(SETTLEMENT_ID, ESCROW_ID, PAYER, PAYEE, 0);
    }

    function testSettlementStoredCorrectly() public {
        engine.recordSettlement(SETTLEMENT_ID, ESCROW_ID, PAYER, PAYEE, AMOUNT);

        ISettlementEngine.Settlement memory settlement = engine.getSettlement(SETTLEMENT_ID);

        assertEq(settlement.id, SETTLEMENT_ID);
        assertEq(settlement.escrowId, ESCROW_ID);
        assertEq(settlement.payer, PAYER);
        assertEq(settlement.payee, PAYEE);
    }

    function testSettlementAmountPersisted() public {
        engine.recordSettlement(SETTLEMENT_ID, ESCROW_ID, PAYER, PAYEE, AMOUNT);

        ISettlementEngine.Settlement memory settlement = engine.getSettlement(SETTLEMENT_ID);

        assertEq(settlement.amount, AMOUNT);
    }

    function testSettlementTimestampSet() public {
        engine.recordSettlement(SETTLEMENT_ID, ESCROW_ID, PAYER, PAYEE, AMOUNT);

        ISettlementEngine.Settlement memory settlement = engine.getSettlement(SETTLEMENT_ID);

        assertGt(settlement.settledAt, 0);
    }

    function testExistsReturnsFalseForUnknownSettlement() public view {
        assertFalse(engine.exists(keccak256("unknown-settlement")));
    }

    function testGetUnknownSettlementReverts() public {
        vm.expectRevert();

        engine.getSettlement(keccak256("unknown-settlement"));
    }

    function testDifferentSettlementIdsCanExist() public {
        engine.recordSettlement(SETTLEMENT_ID, ESCROW_ID, PAYER, PAYEE, AMOUNT);

        engine.recordSettlement(SETTLEMENT_ID_2, keccak256("escrow-2"), PAYER, PAYEE, 2 ether);

        assertTrue(engine.exists(SETTLEMENT_ID));
        assertTrue(engine.exists(SETTLEMENT_ID_2));
    }
}
