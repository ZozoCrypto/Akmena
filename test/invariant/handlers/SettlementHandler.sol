// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SettlementEngine} from "../../../src/economics/SettlementEngine.sol";
import {LibStorage} from "../../../src/storage/LibStorage.sol";

contract SettlementHandler is Test {
    SettlementEngine public immutable settlementEngine;

    bytes32[] public recordedSettlementIds;
    mapping(bytes32 => uint256) public settlementAmounts;
    mapping(bytes32 => address) public settlementPayers;
    mapping(bytes32 => address) public settlementPayees;

    uint256 public recordCount;
    uint256 public duplicateRecordAttempts;
    uint256 public duplicateRecordSuccesses;

    constructor(SettlementEngine _settlementEngine) {
        settlementEngine = _settlementEngine;
    }

    function recordSettlement(bytes32 settlementId, address payer, address payee, uint256 amount) external {
        settlementId = settlementId == bytes32(0) ? keccak256(abi.encodePacked(block.timestamp, msg.sender, block.prevrandao)) : settlementId;
        payer = payer == address(0) ? address(0x1) : payer;
        payee = payee == address(0) ? address(0x2) : payee;
        amount = bound(amount, 1, type(uint128).max);

        bool existsBefore = settlementEngine.exists(settlementId);

        try settlementEngine.recordSettlement(settlementId, payer, payee, amount) {
            recordCount++;
            if (!existsBefore) {
                recordedSettlementIds.push(settlementId);
                settlementAmounts[settlementId] = amount;
                settlementPayers[settlementId] = payer;
                settlementPayees[settlementId] = payee;
            } else {
                duplicateRecordSuccesses++;
            }
        } catch {
            if (existsBefore) {
                duplicateRecordAttempts++;
            }
        }
    }

    function recordedIdsLength() external view returns (uint256) {
        return recordedSettlementIds.length;
    }
}
