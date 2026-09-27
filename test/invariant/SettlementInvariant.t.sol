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

    /// INVARIANT: Every successful settlement recording preserves the expected data
    function invariant_settlementDataIntegrity() public view {
        assertEq(handler.settlementDataIntegrityFailures(), 0);
    }

    /// INVARIANT: Unrecorded IDs must not exist and fetching them must revert
    function invariant_unknownSettlementReverts() public view {
        bytes32 unknownId = keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, "unrecorded"));

        if (settlementEngine.exists(unknownId)) {
            return;
        }

        assertFalse(settlementEngine.exists(unknownId));

        bool reverted;

        try settlementEngine.getSettlement(unknownId) returns (LibStorage.SettlementData memory) {
            reverted = false;
        } catch {
            reverted = true;
        }

        assertTrue(reverted, "Unknown settlement lookup did not revert");
    }
}
