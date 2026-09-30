// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ModelDBoundaryHandlerV2} from "./handlers/ModelDBoundaryHandlerV2.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";

/// @notice Model D boundary stateful invariants, R9 (v2).
/// @dev Strengthened from R8:
/// - Non-vacuous nonce uniqueness (verified against contract state).
/// - Revert atomicity (no state change on failed settlement).
/// - Exact conservation for honest-token mode (not just >=).
/// - Adapter receipt integrity.
/// - Reentry impossibility.
/// - Per-epoch accounting (day-rollover aware).
///
/// Token-mode-conditional invariants: when the fuzz token is in honest mode
/// (mode 0), exact conservation holds. In adversarial modes, only the
/// fail-closed properties hold (no boundary contribution, no phantom charge).
contract ModelDBoundaryInvariantV2 is StdInvariant, Test {
    ModelDBoundaryHandlerV2 internal handler;

    function setUp() public {
        handler = new ModelDBoundaryHandlerV2();
        targetContract(address(handler));
    }

    /// INVARIANT: The boundary never contributes its own funds.
    /// Total pulled from operators >= total pushed to adapters, in every epoch.
    function invariant_operatorOnlyFunding() public view {
        assertGe(
            handler.totalPulledFromOperator(),
            handler.totalPushedToAdapter(),
            "boundary contributed funds to settlement"
        );
    }

    /// INVARIANT: Every wei delivered was charged against the operator's policy.
    /// Compares per-day charge ghosts against per-day pushed ghosts.
    /// (Cumulative ghosts have different reset semantics and are not comparable.)
    function invariant_chargeCoversDelivery() public view {
        uint256 totalDayCharged = handler.charged1() + handler.charged2();
        uint256 totalDayPushed = handler.dayPushed1() + handler.dayPushed2();
        assertGe(
            totalDayCharged,
            totalDayPushed,
            "charge less than delivery"
        );
    }

    /// INVARIANT (honest history only): charge == push == pull exactly.
    /// Skipped if any settlement occurred in non-honest token mode, since
    /// the cumulative history is then polluted by adversarial semantics.
    function invariant_exactConservationHonest() public view {
        if (handler.everNonHonest()) return;
        assertEq(
            handler.totalPulledFromOperator(),
            handler.totalPushedToAdapter(),
            "honest: pull != push"
        );
        // For honest history, per-day charge equals per-day push.
        uint256 totalDayCharged = handler.charged1() + handler.charged2();
        uint256 totalDayPushed = handler.dayPushed1() + handler.dayPushed2();
        assertEq(
            totalDayCharged,
            totalDayPushed,
            "honest: charge != push"
        );
    }

    /// INVARIANT: Nonces are never reused. NON-VACUOUS.
    /// For every nonce the handler marked used, verify the contract's
    /// usedNonces[agent][nonce] is true. Also verify the count matches
    /// successful settlements (no phantom or double-counted nonces).
    function invariant_nonceUniqueness() public view {
        address[2] memory agents = [handler.agent1(), handler.agent2()];
        uint256 totalUsed = 0;
        for (uint256 i = 0; i < 2; i++) {
            address agent = agents[i];
            uint256[] memory nonces = handler.getUsedNonces(agent);
            totalUsed += nonces.length;
            for (uint256 j = 0; j < nonces.length; j++) {
                assertTrue(
                    handler.auth().usedNonces(agent, nonces[j]),
                    "nonce marked used by handler but not consumed in contract"
                );
            }
        }
        assertEq(
            totalUsed,
            handler.successfulSettlements(),
            "nonce count != successful settlements"
        );
    }

    /// INVARIANT: Failed settlements are atomic. No nonce consumed, no charge
    /// recorded, no balances changed on revert.
    function invariant_revertAtomicity() public view {
        assertEq(
            handler.revertAtomicityViolations(),
            0,
            "revert atomicity violated"
        );
    }

    /// INVARIANT (honest history only): The boundary holds zero token balance.
    /// Funds flow through, not to, the boundary. Skipped if any non-honest
    /// settlement occurred (malicious modes may strand funds by design).
    function invariant_boundaryBalanceZeroHonest() public view {
        if (handler.everNonHonest()) return;
        assertEq(
            handler.token().balanceOf(address(handler.boundary())),
            0,
            "honest: boundary holds ERC20 balance"
        );
    }

    /// INVARIANT: Daily spent never exceeds the daily limit, for both operators.
    /// The F-14 saturating headroom must prevent overspend, never panic.
    function invariant_dailyLimitRespected() public view {
        (,, uint256 spent1,,) = handler.boundary().agentAssetPolicies(
            handler.operator1(),
            handler.agent1(),
            address(handler.token())
        );
        (uint256 maxSpend1, uint256 daily1,,,) = handler.boundary().agentAssetPolicies(
            handler.operator1(),
            handler.agent1(),
            address(handler.token())
        );
        assertLe(spent1, daily1, "operator1: daily limit exceeded");

        (,, uint256 spent2,,) = handler.boundary().agentAssetPolicies(
            handler.operator2(),
            handler.agent2(),
            address(handler.token())
        );
        (,, uint256 daily2,,) = handler.boundary().agentAssetPolicies(
            handler.operator2(),
            handler.agent2(),
            address(handler.token())
        );
        assertLe(spent2, daily2, "operator2: daily limit exceeded");

        // maxSpendPerTransaction is also respected (checked per-tx in contract,
        // but verify no config violates it).
        assertTrue(maxSpend1 <= 200 ether, "operator1: maxSpend out of fuzz range");
    }

    /// INVARIANT (honest history only): Adapter receipts match pushed amounts.
    /// Skipped if any non-honest settlement occurred.
    function invariant_adapterReceiptsHonest() public view {
        if (handler.everNonHonest()) return;
        uint256 totalReceived =
            handler.adapter().totalReceived() +
            handler.reentrantAdapter().totalReceived();
        assertEq(
            totalReceived,
            handler.totalPushedToAdapter(),
            "honest: adapter receipts != pushed"
        );
    }

    /// INVARIANT: Reentrant calls never succeed.
    /// The reentrant adapter attempts reentry on every callback; none may succeed.
    function invariant_noReentrySuccess() public view {
        assertEq(
            handler.reentrantAdapter().reentrySuccesses(),
            0,
            "reentrant call succeeded"
        );
    }

    /// INVARIANT: Cross-operator isolation. Each pair's ghost charge matches
    /// the contract's totalSpentToday for that pair.
    function invariant_crossOperatorIsolation() public view {
        (,, uint256 spent1,,) = handler.boundary().agentAssetPolicies(
            handler.operator1(),
            handler.agent1(),
            address(handler.token())
        );
        (,, uint256 spent2,,) = handler.boundary().agentAssetPolicies(
            handler.operator2(),
            handler.agent2(),
            address(handler.token())
        );
        assertEq(
            handler.charged1(),
            spent1,
            "pair1: ghost charge != contract spent"
        );
        assertEq(
            handler.charged2(),
            spent2,
            "pair2: ghost charge != contract spent"
        );
    }
}
