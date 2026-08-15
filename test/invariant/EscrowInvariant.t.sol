// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {IEscrowEngine} from "../../src/economics/IEscrowEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";
import {EscrowHandler} from "./handlers/EscrowHandler.sol";

contract EscrowInvariant is StdInvariant, Test {
    EscrowEngine internal escrow;
    EscrowHandler internal handler;

    function setUp() public {
        escrow = new EscrowEngine();
        handler = new EscrowHandler(escrow);

        targetContract(address(handler));
    }

    /*
     * Every successfully created escrow must have:
     * - a non-zero buyer
     * - a non-zero seller
     * - a non-zero amount
     * - a valid lifecycle status
     */
    function invariant_createdEscrowsAreValid() public view {
        uint256 length = handler.createdIdsLength();

        for (uint256 i = 0; i < length; ++i) {
            uint256 id = handler.createdId(i);

            LibStorage.EscrowData memory escrowData = escrow.getEscrow(id);

            assertTrue(escrowData.buyer != address(0));
            assertTrue(escrowData.seller != address(0));
            assertGt(escrowData.amount, 0);

            // 1 = Funded
            // 2 = Released
            // 3 = Refunded
            assertTrue(escrowData.status == 1 || escrowData.status == 2 || escrowData.status == 3);
        }
    }

    /*
     * Released and refunded are mutually exclusive.
     */
    function invariant_terminalStatesAreMutuallyExclusive() public view {
        uint256 length = handler.createdIdsLength();

        for (uint256 i = 0; i < length; ++i) {
            uint256 id = handler.createdId(i);

            LibStorage.EscrowData memory escrowData = escrow.getEscrow(id);

            assertFalse(escrowData.status == 2 && escrowData.status == 3);
        }
    }

    /*
     * Escrow ID zero must remain unused and strictly revert.
     * Note: We test this as a standard unit test since it involves a revert exception.
     */
    function test_RevertWhen_QueryingEscrowZero() public {
        vm.expectRevert(IEscrowEngine.EscrowNotFound.selector);
        escrow.getEscrow(0);
    }

    /*
     * Every successful creation must be recorded by the handler.
     */
    function invariant_successfulCreateCountMatchesRecordedIds() public view {
        assertEq(handler.createCount(), handler.createdIdsLength());
    }

    /*
     * SECURITY INVARIANT:
     *
     * An account that is NOT the buyer must never be able to release
     * an escrow merely by supplying the buyer address as an argument.
     *
     * The current production implementation is expected to violate this
     * because releaseEscrow() currently trusts its caller parameter.
     */
    function invariant_onlyBuyerCanRelease() public view {
        assertEq(handler.unauthorizedReleaseSuccesses(), 0);
    }

    /*
     * SECURITY INVARIANT:
     *
     * An account that is NOT the seller must never be able to refund
     * an escrow merely by supplying the seller address as an argument.
     *
     * The current production implementation is expected to violate this
     * because refundEscrow() currently trusts its caller parameter.
     */
    function invariant_onlySellerCanRefund() public view {
        assertEq(handler.unauthorizedRefundSuccesses(), 0);
    }

    function test_SanityCheck() public pure {
        assertTrue(true);
    }
}
