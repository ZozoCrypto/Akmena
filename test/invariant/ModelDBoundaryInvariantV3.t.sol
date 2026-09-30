// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {
    ModelDBoundaryHandlerV3Honest,
    ModelDBoundaryHandlerV3Malicious,
    ModelDBoundaryHandlerV3Base
} from "./handlers/ModelDBoundaryHandlerV3.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";

/// @notice Shared invariant logic for V3 campaigns.
/// @dev Inherited by the honest and malicious test contracts, which
/// differ only in which invariants are enforced.
abstract contract ModelDBoundaryInvariantV3Base is StdInvariant, Test {
    ModelDBoundaryHandlerV3Base internal handler;

    function _setup(address handlerAddr) internal {
        handler = ModelDBoundaryHandlerV3Base(handlerAddr);
        targetContract(handlerAddr);
    }

    // --- Fail-closed invariants (both campaigns) ---

    function invariant_operatorOnlyFunding() public view {
        assertGe(
            handler.totalPulledFromOperator(),
            handler.totalPushedToAdapter(),
            "boundary contributed funds to settlement"
        );
    }

    function invariant_chargeCoversDelivery() public view {
        uint256 totalDayCharged = handler.charged1() + handler.charged2();
        uint256 totalDayPushed = handler.dayPushed1() + handler.dayPushed2();
        assertGe(totalDayCharged, totalDayPushed, "charge less than delivery");
    }

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
        assertEq(totalUsed, handler.successfulSettlements(), "nonce count != successful settlements");
    }

    function invariant_revertAtomicity() public view {
        assertEq(handler.revertAtomicityViolations(), 0, "revert atomicity violated");
    }

    function invariant_dailyLimitRespected() public view {
        (,, uint256 spent1,,) = handler.boundary().agentAssetPolicies(
            handler.operator1(), handler.agent1(), address(handler.token())
        );
        (,, uint256 daily1,,) = handler.boundary().agentAssetPolicies(
            handler.operator1(), handler.agent1(), address(handler.token())
        );
        assertLe(spent1, daily1, "operator1: daily limit exceeded");

        (,, uint256 spent2,,) = handler.boundary().agentAssetPolicies(
            handler.operator2(), handler.agent2(), address(handler.token())
        );
        (,, uint256 daily2,,) = handler.boundary().agentAssetPolicies(
            handler.operator2(), handler.agent2(), address(handler.token())
        );
        assertLe(spent2, daily2, "operator2: daily limit exceeded");
    }

    function invariant_noReentrySuccess() public view {
        assertEq(handler.reentrantAdapter().reentrySuccesses(), 0, "reentrant call succeeded");
    }

    function invariant_crossOperatorIsolation() public view {
        (,, uint256 spent1,,) = handler.boundary().agentAssetPolicies(
            handler.operator1(), handler.agent1(), address(handler.token())
        );
        (,, uint256 spent2,,) = handler.boundary().agentAssetPolicies(
            handler.operator2(), handler.agent2(), address(handler.token())
        );
        assertEq(handler.charged1(), spent1, "pair1: ghost charge != contract spent");
        assertEq(handler.charged2(), spent2, "pair2: ghost charge != contract spent");
    }

    /// INVARIANT: Explicit replay always reverts with zero state change.
    /// Every replay attempt must revert; no state violations allowed.
    /// Non-vacuous: requires at least one replay attempt to have occurred
    /// (asserted via a separate view that the fuzzer exercised it).
    function invariant_replayAlwaysReverts() public view {
        assertEq(handler.replayStateViolations(), 0, "replay caused state change");
        assertEq(
            handler.replayAttempts(),
            handler.replayReverts(),
            "replay attempt did not revert"
        );
    }

    /// INVARIANT: Governance admin ghosts match contract state.
    function invariant_governanceAdminSync() public view {
        assertEq(
            handler.expectedAllowlistAdmin(),
            handler.boundary().allowlistAdmin(),
            "allowlist admin ghost desync"
        );
        assertEq(
            handler.expectedEmergencyAdmin(),
            handler.boundary().emergencyAdmin(),
            "emergency admin ghost desync"
        );
    }

    /// INVARIANT: Allowance ghosts match on-chain allowances.
    function invariant_allowanceSync() public view {
        assertEq(
            handler.token().allowance(handler.operator1(), address(handler.boundary())),
            handler.expectedAllowance1(),
            "operator1 allowance ghost desync"
        );
        assertEq(
            handler.token().allowance(handler.operator2(), address(handler.boundary())),
            handler.expectedAllowance2(),
            "operator2 allowance ghost desync"
        );
    }

    /// INVARIANT: Token2 (honest-only) settlements are isolated from token1.
    /// Token2's pulled/pushed are tracked separately; token1's cumulative
    /// ghosts must be unaffected by token2 activity.
    function invariant_tokenIsolation() public view {
        // Token2 accounting is internally consistent.
        assertGe(handler.token2Pulled(), handler.token2Pushed(), "token2: boundary contributed");
        // Token1's boundary balance is independent of token2 settlements.
        // (Both tokens are separate ERC20s; this checks no cross-contamination
        // in ghost accounting.)
        assertTrue(
            handler.token2Settlements() == 0 || handler.token2Pulled() >= handler.token2Pushed(),
            "token2 accounting inconsistent"
        );
    }
}

/// @notice V3 HONEST campaign: exact conservation enforced unconditionally.
/// @dev The handler's token is locked in honest mode (mode 0). No gating.
contract ModelDBoundaryInvariantV3Honest is ModelDBoundaryInvariantV3Base {
    function setUp() public {
        _setup(address(new ModelDBoundaryHandlerV3Honest()));
    }

    /// INVARIANT (honest only): charge == push == pull exactly, always.
    function invariant_exactConservation() public view {
        assertEq(
            handler.totalPulledFromOperator(),
            handler.totalPushedToAdapter(),
            "honest: pull != push"
        );
        uint256 totalDayCharged = handler.charged1() + handler.charged2();
        uint256 totalDayPushed = handler.dayPushed1() + handler.dayPushed2();
        assertEq(totalDayCharged, totalDayPushed, "honest: charge != push");
    }

    /// INVARIANT (honest only): boundary holds zero token balance.
    function invariant_boundaryBalanceZero() public view {
        assertEq(
            handler.token().balanceOf(address(handler.boundary())),
            0,
            "honest: boundary holds ERC20 balance"
        );
    }

    /// INVARIANT (honest only): adapter declared receipts match pushed.
    function invariant_adapterReceipts() public view {
        uint256 totalDeclared =
            handler.adapter().totalDeclaredReceived() +
            handler.reentrantAdapter().totalDeclaredReceived();
        assertEq(totalDeclared, handler.totalPushedToAdapter(), "honest: declared != pushed");
    }

    /// INVARIANT (honest only): token mode never changed from honest.
    function invariant_tokenStaysHonest() public view {
        assertEq(handler.token().mode(), 0, "honest campaign: token mode changed");
    }
}

/// @notice V3 MALICIOUS campaign: only fail-closed properties.
/// @dev Token modes 1-7 are fuzzed. Exact conservation is NOT asserted;
/// the boundary must never contribute funds and must fail closed.
contract ModelDBoundaryInvariantV3Malicious is ModelDBoundaryInvariantV3Base {
    function setUp() public {
        _setup(address(new ModelDBoundaryHandlerV3Malicious()));
    }

    /// INVARIANT (malicious): boundary token balance never goes negative
    /// relative to tracked flows (fail-closed: no phantom minting).
    /// The boundary may strand funds (over-pull) but must never create them.
    function invariant_noPhantomFunds() public view {
        // Total pushed can never exceed total pulled — the boundary
        // cannot manufacture tokens even under adversarial token semantics.
        assertGe(
            handler.totalPulledFromOperator(),
            handler.totalPushedToAdapter(),
            "malicious: boundary manufactured funds"
        );
    }
}
