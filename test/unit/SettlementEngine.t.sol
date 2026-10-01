// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {SettlementEngine} from "../../src/economics/SettlementEngine.sol";
import {ISettlementEngine} from "../../src/economics/ISettlementEngine.sol";

/// @notice Gap-fill unit tests for SettlementEngine.
/// @dev Covers properties from test/unit/SettlementEngine.t.sol.bak that lack
///      active coverage: zero-address/amount validation, exists-false, multiple IDs.
///      The .bak used an old API with escrowId; these target the current
///      recordSettlement(bytes32, address, address, uint256).
contract SettlementEngineGapTest is Test {
    SettlementEngine public engine;

    address public payer = address(0x1001);
    address public payee = address(0x2002);
    bytes32 public sId = keccak256("SETTLEMENT_GAP_1");
    bytes32 public sId2 = keccak256("SETTLEMENT_GAP_2");

    function setUp() public {
        engine = new SettlementEngine();
    }

    function test_CannotUseZeroPayer() public {
        vm.expectRevert(ISettlementEngine.InvalidAddress.selector);
        engine.recordSettlement(sId, address(0), payee, 1 ether);
    }

    function test_CannotUseZeroPayee() public {
        vm.expectRevert(ISettlementEngine.InvalidAddress.selector);
        engine.recordSettlement(sId, payer, address(0), 1 ether);
    }

    function test_CannotUseZeroAmount() public {
        vm.expectRevert(ISettlementEngine.InvalidAmount.selector);
        engine.recordSettlement(sId, payer, payee, 0);
    }

    function test_ExistsReturnsFalseForUnknown() public view {
        assertFalse(engine.exists(keccak256("unknown-settlement")));
    }

    function test_DifferentIdsCanExist() public {
        engine.recordSettlement(sId, payer, payee, 1 ether);
        engine.recordSettlement(sId2, payer, payee, 2 ether);

        assertTrue(engine.exists(sId));
        assertTrue(engine.exists(sId2));
    }
}
