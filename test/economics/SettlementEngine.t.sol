// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SettlementEngine} from "../../src/economics/SettlementEngine.sol";
import {ISettlementEngine} from "../../src/economics/ISettlementEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";

contract SettlementEngineTest is Test {
    SettlementEngine public engine;
    address public payer = address(0x999);
    address public payee = address(0x888);
    bytes32 public sId = keccak256("SETTLEMENT_1");

    function setUp() public {
        engine = new SettlementEngine();
    }

    function test_RecordSettlement() public {
        vm.expectEmit(true, true, true, true);
        emit ISettlementEngine.SettlementRecorded(sId, payer, payee, 1500);

        engine.recordSettlement(sId, payer, payee, 1500);
        assertTrue(engine.exists(sId));

        LibStorage.SettlementData memory data = engine.getSettlement(sId);
        assertEq(data.payer, payer);
        assertEq(data.payee, payee);
        assertEq(data.amount, 1500);
        assertEq(data.timestamp, block.timestamp);
    }

    function test_RevertWhen_DuplicateSettlement() public {
        engine.recordSettlement(sId, payer, payee, 1500);
        vm.expectRevert(ISettlementEngine.SettlementAlreadyExists.selector);
        engine.recordSettlement(sId, payer, payee, 2000);
    }

    function test_RevertWhen_SettlementNotFound() public {
        vm.expectRevert(ISettlementEngine.SettlementNotFound.selector);
        engine.getSettlement(sId);
    }
}
