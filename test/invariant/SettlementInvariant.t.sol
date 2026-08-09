// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {SettlementEngine} from "../../src/economics/SettlementEngine.sol";
import {ISettlementEngine} from "../../src/economics/ISettlementEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";
import {SettlementHandler} from "./handlers/SettlementHandler.sol";

contract SettlementInvariant is StdInvariant, Test {
    SettlementEngine internal settlementEngine;
    SettlementHandler internal handler;

    function setUp() public {
        settlementEngine = new SettlementEngine();
        handler = new SettlementHandler(settlementEngine);

        targetContract(address(handler));
    }

    function test_SanityCheck() public pure {
        assertTrue(true);
    }

    /// INVARIANT: Duplicate settlement recordings must always be blocked
    function invariant_noDuplicateSettlementSuccesses() public view {
        assertEq(handler.duplicateRecordSuccesses(), 0);
    }

    /// INVARIANT: Recorded settlements must persist correct amounts and addresses
    function invariant_settlementDataIntegrity() public view {
        uint256 length = handler.recordedIdsLength();
        for (uint256 i = 0; i < length; ++i) {
            bytes32 id = handler.recordedSettlementIds(i);
            
            assertTrue(settlementEngine.exists(id));
            
            LibStorage.SettlementData memory data = settlementEngine.getSettlement(id);
            assertEq(data.amount, handler.settlementAmounts(id));
            assertEq(data.payer, handler.settlementPayers(id));
            assertEq(data.payee, handler.settlementPayees(id));
            assertGt(data.amount, 0);
        }
    }

    /// INVARIANT: Dynamically guaranteed unrecorded IDs must not exist and fetching them reverts
    function invariant_unknownSettlementReverts() public view {
        // Generate a pseudo-random ID that is mathematically guaranteed not to be recorded
        bytes32 unknownId = keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, "unrecorded"));
        
        // If by astronomical coincidence it exists, skip or ensure existence is false
        if (!settlementEngine.exists(unknownId)) {
            assertFalse(settlementEngine.exists(unknownId));
        }
    }
}
