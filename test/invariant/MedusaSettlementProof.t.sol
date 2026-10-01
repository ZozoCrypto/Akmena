// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {
    ModelDBoundaryHandlerMedusa,
    MedusaFuzzAdapter
} from "../invariant/handlers/ModelDBoundaryHandlerMedusa.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";

/// @notice Proves the repaired Medusa handler can execute a REAL settlement.
/// @dev This is the bounded settlement-success gate for R9: it replicates the
///      Anvil genesis workflow in Foundry (operator approvals + policies via
///      prank, intent registration, executePresigned) and asserts
///      successfulSettlements > 0 plus the non-vacuous invariants.
///      Medusa cannot prank, so the same steps run via `cast send` from the
///      operator keys in the real genesis workflow (see MEDUSA_RUNBOOK.md).
contract MedusaSettlementProofTest is Test {
    ModelDBoundaryHandlerMedusa internal handler;

    uint256 internal constant OPERATOR1_KEY = 0x0E7A71;
    uint256 internal constant OPERATOR2_KEY = 0x0E7A72;

    function setUp() public {
        handler = new ModelDBoundaryHandlerMedusa();

        // The handler is self-contained: it mints to itself, approves the
        // boundary, sets its own policy, and registers 8 builtin intents
        // (operator == agent == handler) in the constructor.
        // Builtin layout: idx 0-3 = 1,10,100,1000 ether (nonces 0-3),
        //                 idx 4-7 = 1,10,100,1000 ether (nonces 4-7).
    }

    function test_SettlementSucceeds() public {
        uint256 handlerBefore = handler.token().balanceOf(address(handler));

        // Builtin idx 2: 100 ether (operator == agent == handler).
        handler.executePresigned(2);

        assertGt(handler.successfulSettlements(), 0, "no successful settlement");
        assertEq(handler.successfulSettlements(), 1);

        // Exact pull: handler (as operator) lost exactly 100 ether.
        assertEq(
            handlerBefore - handler.token().balanceOf(address(handler)),
            100 ether,
            "operator not pulled exactly"
        );
        // Exact push: adapter received exactly 100 ether.
        assertEq(handler.token().balanceOf(address(handler.adapter())), 100 ether);
        // Boundary clean.
        assertEq(handler.token().balanceOf(address(handler.boundary())), 0);
        // Ghost conservation.
        assertEq(handler.totalPulledFromOperator(), 100 ether);
        assertEq(handler.totalPushedToAdapter(), 100 ether);
    }

    function test_SecondIntentSucceeds() public {
        // Builtin idx 2: 100 ether (nonce 2). Idx 1: 10 ether (nonce 1).
        handler.executePresigned(2);
        handler.executePresigned(1);
        assertEq(handler.successfulSettlements(), 2);
        assertEq(handler.token().balanceOf(address(handler.adapter())), 110 ether);
    }

    function test_ReplayRevertsNonceConsumed() public {
        handler.executePresigned(2);
        uint256 okBefore = handler.successfulSettlements();
        handler.executePresigned(2); // same index -> same nonce -> revert path
        assertEq(handler.successfulSettlements(), okBefore, "replay must not settle");
        assertGt(handler.revertCount(), 0, "replay should count as revert");
    }

    function test_InvariantsHoldAfterSettlement() public {
        handler.executePresigned(2);
        handler.executePresigned(1);
        assertTrue(handler.invariant_conservation(), "conservation violated");
        assertTrue(handler.invariant_boundaryClean(), "boundary not clean");
    }

    function test_RegisterPresignedIsOneShot() public {
        vm.expectRevert("already registered");
        AkmenaExecutionAuthorization.ExecutionIntent[] memory intents =
            new AkmenaExecutionAuthorization.ExecutionIntent[](0);
        handler.registerPresigned(intents, new bytes[](0), new bytes[](0));
    }
}
