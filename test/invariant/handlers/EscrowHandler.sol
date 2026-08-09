// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";
import {LibStorage} from "../../../src/storage/LibStorage.sol";

contract EscrowHandler is Test {
    EscrowEngine public immutable escrow;

    uint256[] public createdIds;

    uint256 public createCount;
    uint256 public releaseCount;
    uint256 public refundCount;

    // Security violation counters
    uint256 public unauthorizedReleaseSuccesses;
    uint256 public unauthorizedRefundSuccesses;

    constructor(EscrowEngine _escrow) {
        escrow = _escrow;
    }

    function createEscrow(address buyer, address seller, uint256 amount) external {
        buyer = _nonZero(buyer);
        seller = _nonZero(seller);
        amount = bound(amount, 1, type(uint128).max);

        try escrow.createEscrow(buyer, seller, amount) returns (uint256 id) {
            createdIds.push(id);
            createCount++;
        } catch {}
    }

    function releaseEscrow(uint256 index, address attacker) external {
        if (createdIds.length == 0) return;
        uint256 id = createdIds[index % createdIds.length];
        LibStorage.EscrowData memory target = escrow.getEscrow(id);

        if (attacker == target.buyer) {
            attacker = address(uint160(attacker) ^ 1);
        }

        // 1. THE ATTACK: Fuzzed address tries to hack the release
        vm.prank(attacker);
        try escrow.releaseEscrow(id) {
            unauthorizedReleaseSuccesses++;
        } catch {}

        // 2. THE PROGRESSION: Legitimate buyer releases to progress state
        vm.prank(target.buyer);
        try escrow.releaseEscrow(id) {
            releaseCount++;
        } catch {}
    }

    function refundEscrow(uint256 index, address attacker) external {
        if (createdIds.length == 0) return;
        uint256 id = createdIds[index % createdIds.length];
        LibStorage.EscrowData memory target = escrow.getEscrow(id);

        if (attacker == target.seller) {
            attacker = address(uint160(attacker) ^ 1);
        }

        // 1. THE ATTACK: Fuzzed address tries to hack the refund
        vm.prank(attacker);
        try escrow.refundEscrow(id) {
            unauthorizedRefundSuccesses++;
        } catch {}

        // 2. THE PROGRESSION: Legitimate seller refunds to progress state
        vm.prank(target.seller);
        try escrow.refundEscrow(id) {
            refundCount++;
        } catch {}
    }

    function createdIdsLength() external view returns (uint256) {
        return createdIds.length;
    }

    function createdId(uint256 index) external view returns (uint256) {
        return createdIds[index];
    }

    function _nonZero(address value) internal pure returns (address) {
        if (value == address(0)) {
            return address(1);
        }
        return value;
    }
}
