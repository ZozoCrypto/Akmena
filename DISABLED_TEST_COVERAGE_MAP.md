# Disabled Test Coverage Map
**Date:** 2026-10-01 · **Branch:** `feature/model-d-operator-custody` · **HEAD:** `e9452b46`

## Summary

| Disabled File | Tests | Covered | Gaps Filled | Obsolete |
|---|---|---|---|---|
| `test/unit/AgreementEngine.t.sol.bak` | 18 | 0 | 0 | 18 (API removed) |
| `test/unit/EscrowEngine.t.sol.bak` | 8 | 0 | 8 (new API) | 8 (old native-ETH API) |
| `test/unit/SettlementEngine.t.sol.bak` | 11 | 6 | 5 | 0 |
| `Attack_NativeValueSubstitution.t.sol.disabled` | 1 | 1 (property) | 0 | 1 (tests disabled fn) |
| `test/chaos/AdversarialChaos.t.sol.bak` | 1 | 1 (invariant) | 0 | 1 (old API) |
| `test/symbolic/AkmenaSymbolic.t.sol.bak` | 2 | 2 | 0 | 0 |
| **Total** | **41** | **10** | **13** | **28** |

---

## 1. `test/unit/AgreementEngine.t.sol.bak` (18 tests) — OBSOLETE

**Reason:** The .bak tests target an API that no longer exists. The old `AgreementEngine` had:
- `propose(bytes32, bytes32, bytes32, string)` with bytes32 agent IDs and string termsURI
- `accept(bytes32)`, `reject(bytes32)`, `complete(bytes32)` lifecycle
- Returned `IAgreementEngine.Agreement` struct

The current `src/autonomous/AgreementEngine.sol` has:
- `createAgreement(bytes32, address, bytes32, uint256)` with address partyB and bytes32 termsHash
- `executeAgreement(bytes32)` (no accept/reject/complete)
- Returns `LibStorage.AgreementData` struct

The propose→accept→reject→complete state machine was removed. These 18 tests cannot be mapped.

**Active coverage for new API:** `test/autonomous/AgreementEngine.t.sol` (4 tests):
- `test_CreateAgreement`
- `test_ExecuteAgreement`
- `test_RevertWhen_UnauthorizedExecution`
- `test_RevertWhen_AgreementExpired`

| Disabled Test | Assertion | Active Coverage? | Verdict |
|---|---|---|---|
| testProposeAgreement | propose() creates agreement, exists() true | No (propose removed) | OBSOLETE |
| testCannotCreateDuplicateAgreement | duplicate propose reverts AgreementAlreadyExists | No | OBSOLETE |
| testCannotCreateAgreementTwiceAfterRead | read doesn't allow re-propose | No | OBSOLETE |
| testDifferentAgreementIdsCanExist | two IDs coexist | No | OBSOLETE |
| testCannotCreateAgreementWithEmptyTerms | empty termsURI reverts InvalidTerms | No | OBSOLETE |
| testGetUnknownAgreementReverts | get unknown reverts AgreementNotFound | No | OBSOLETE |
| testAgreementStoredCorrectly | proposer/counterparty/termsURI persisted | No | OBSOLETE |
| testAgreementAgentsPersistedCorrectly | agents persisted | No | OBSOLETE |
| testTermsURIPersistedCorrectly | termsURI persisted | No | OBSOLETE |
| testAgreementStatusStartsAsProposed | status == Proposed | No (no status enum) | OBSOLETE |
| testAgreementTimestampSet | createdAt > 0 | No | OBSOLETE |
| testExistsReturnsFalseForUnknownAgreement | exists(unknown) == false | No | OBSOLETE |
| testAcceptAgreement | accept() → Accepted, acceptedAt > 0 | No (accept removed) | OBSOLETE |
| testRejectAgreement | reject() → Rejected | No (reject removed) | OBSOLETE |
| testCompleteAgreement | accept→complete → Completed | No (complete removed) | OBSOLETE |
| testCannotCompleteBeforeAccept | complete before accept reverts | No | OBSOLETE |
| testCannotAcceptTwice | double accept reverts | No | OBSOLETE |
| testCannotRejectAfterAccept | reject after accept reverts | No | OBSOLETE |

---

## 2. `test/unit/EscrowEngine.t.sol.bak` (8 tests) — OBSOLETE (old API), GAPS FILLED (new API)

**Reason for OBSOLETE:** The .bak tests target native-ETH escrow:
- `createEscrow{value:}(bytes32, address)` with bytes32 ID and msg.value funding

The current `src/economics/EscrowEngine.sol` is ERC20-based:
- `createEscrow(address buyer, address seller, uint256 amount)` returns uint256 ID
- `createEscrow(address, address, uint256, bytes32)` with referenceId
- `createEscrow(address, address, address, uint256)` with explicit asset
- Funding via `safeTransferFrom` (buyer must approve), not msg.value
- `releaseEscrow(uint256)` and `refundEscrow(uint256)` (not `release(bytes32)`)

**Active coverage before this work:** None in `test/unit/`. Covered by:
- `test/invariant/EscrowInvariant.t.sol` (5 invariants, 500k calls)
- `test/chaos/AkmenaChaos.t.sol` (fuzz, 5k runs)

**Gaps filled:** New unit tests written for the ERC20 API in `test/unit/EscrowEngine.t.sol`,
covering the same *properties* as the .bak (not the same signatures):
- Create escrow (buyer/seller/amount/asset)
- Duplicate prevention (via referenceId)
- Unknown escrow revert
- Stored correctly (id, buyer, seller, amount, asset)
- Release escrow (funds to seller)
- Cannot release twice
- Exists false for unknown
- Zero address/amount validation

| Disabled Test | Assertion | Active Coverage? | Verdict |
|---|---|---|---|
| testCreateEscrow | native ETH create, exists true | No (native API removed) | OBSOLETE → Replaced |
| testCannotCreateDuplicateEscrow | duplicate bytes32 ID reverts | No | OBSOLETE → Replaced |
| testGetUnknownEscrowReverts | get unknown reverts EscrowNotFound | No | OBSOLETE → Replaced |
| testEscrowStoredCorrectly | id/payer/payee/amount persisted | No | OBSOLETE → Replaced |
| testEscrowStartsFunded | contract balance == amount | No (ERC20 now) | OBSOLETE → Replaced |
| testReleaseEscrow | release pays payee, marks released | Invariant only | OBSOLETE → Replaced |
| testCannotReleaseTwice | double release reverts | Invariant only | OBSOLETE → Replaced |
| testExistsReturnsFalseForUnknownEscrow | exists(unknown) == false | No | OBSOLETE → Replaced |

---

## 3. `test/unit/SettlementEngine.t.sol.bak` (11 tests) — PARTIAL, GAPS FILLED

**API change:** Old: `recordSettlement(bytes32, bytes32, address, address, uint256)` (with escrowId).
New: `recordSettlement(bytes32, address, address, uint256)` (no escrowId).

**Active coverage:** `test/economics/SettlementEngine.t.sol` (3 tests).

| Disabled Test | Assertion | Active Coverage? | File:Line | Verdict |
|---|---|---|---|---|
| testRecordSettlement | record → exists true | YES | test/economics/SettlementEngine.t.sol:19 `test_RecordSettlement` | COVERED |
| testCannotCreateDuplicateSettlement | duplicate reverts | YES | test/economics/SettlementEngine.t.sol:33 `test_RevertWhen_DuplicateSettlement` | COVERED |
| testCannotUseZeroPayer | zero payer reverts | NO | — | GAP → Filled |
| testCannotUseZeroPayee | zero payee reverts | NO | — | GAP → Filled |
| testCannotUseZeroAmount | zero amount reverts | NO | — | GAP → Filled |
| testSettlementStoredCorrectly | id/escrowId/payer/payee persisted | PARTIAL (no escrowId in new API; id/payer/payee covered) | test/economics/SettlementEngine.t.sol:19 | COVERED |
| testSettlementAmountPersisted | amount persisted | YES | test/economics/SettlementEngine.t.sol:19 | COVERED |
| testSettlementTimestampSet | settledAt > 0 | YES | test/economics/SettlementEngine.t.sol:19 | COVERED |
| testExistsReturnsFalseForUnknownSettlement | exists(unknown) == false | NO | — | GAP → Filled |
| testGetUnknownSettlementReverts | get unknown reverts | YES | test/economics/SettlementEngine.t.sol:39 `test_RevertWhen_SettlementNotFound` | COVERED |
| testDifferentSettlementIdsCanExist | two IDs coexist | NO | — | GAP → Filled |

**New tests added:** `test/unit/SettlementEngine.t.sol` (5 tests):
- `test_CannotUseZeroPayer`
- `test_CannotUseZeroPayee`
- `test_CannotUseZeroAmount`
- `test_ExistsReturnsFalseForUnknown`
- `test_DifferentIdsCanExist`

---

## 4. `test/attack/phase_p_execution_authorization/Attack_NativeValueSubstitution.t.sol.disabled` (1 test) — OBSOLETE

**Reason:** Tests `boundary.executeAgentCall{value:}()`, which is now intentionally disabled:
```solidity
function executeAgentCall(address, address, uint256, bytes32, uint256, bytes calldata)
    external pure returns (bytes memory)
{
    revert LegacyExecutionDisabled();
}
```
The test asserts that native value substitution *succeeds* (callCount==2, lastValue==100 ether) — i.e., it documents the VULNERABILITY, not the fix. The vulnerability was fixed by:
1. Disabling `executeAgentCall` entirely
2. `executeAuthorizedAgentCall` enforcing `NativeValueMismatch()` unless `msg.value == intent.value == intent.amount`

**Active coverage of the security property:**
- `test/attack/phase_p_execution_authorization/Attack_ProductionExecutionSemantics.t.sol` — native value binding
- `test/attack/phase_p_execution_authorization/Attack_CriticalEconomicLimitBypass.t.sol` — economic limits

| Disabled Test | Assertion | Active Coverage? | Verdict |
|---|---|---|---|
| test_Attack_NativeValueIsNotBoundToAuthorization | substitution succeeds (documents vuln) | YES (property fixed & tested) | OBSOLETE |

---

## 5. `test/chaos/AdversarialChaos.t.sol.bak` (1 test) — OBSOLETE (old API), PROPERTY COVERED

**Reason:** Tests native-ETH escrow (`createEscrow{value:}(bytes32, address)`, `release(bytes32)`, `refund(bytes32)`).
Current API is ERC20-based with uint256 IDs and `releaseEscrow(uint256)`/`refundEscrow(uint256)`.

**Property (double-release / state collision protection):** COVERED by invariant:
- `test/invariant/EscrowInvariant.t.sol:55` `invariant_terminalStatesAreMutuallyExclusive` — asserts released and refunded are mutually exclusive across 500k fuzz calls.

| Disabled Test | Assertion | Active Coverage? | File:Line | Verdict |
|---|---|---|---|---|
| test_Chaos_ConcurrentEscrowState | double-release reverts; refund-after-release reverts | YES (invariant) | test/invariant/EscrowInvariant.t.sol:55 | OBSOLETE (API) / COVERED (property) |

---

## 6. `test/symbolic/AkmenaSymbolic.t.sol.bak` (2 tests) — COVERED

| Disabled Test | Assertion | Active Coverage? | File:Line | Verdict |
|---|---|---|---|---|
| test_symbolic_unauthorizedRegisterReverts | non-deployer registerModule reverts | YES | test/attack/phase_a_core/Attack_CoreAuthority.t.sol:32 `test_Attack_UnauthorizedModuleOverwrite` | COVERED |
| test_symbolic_unregisteredEscrowHasZeroPayer | unknown escrow ID → exists false | YES (property) | test/invariant/EscrowInvariant.t.sol:33 `invariant_createdEscrowsAreValid` + new unit test `test_ExistsReturnsFalseForUnknown` | COVERED |

Note: `test_Attack_UnauthorizedModuleOverwrite` uses a fixed attacker address (not symbolic), but asserts the same property: non-deployer cannot register. The symbolic version is stronger (forall caller), but the property is covered.

---

## Files Created

1. **`test/unit/EscrowEngine.t.sol`** — 8 unit tests for the current ERC20-based EscrowEngine API, covering the properties from the .bak (create, duplicate prevention, unknown revert, storage, release, double-release, exists, validation).

2. **`test/unit/SettlementEngine.t.sol`** — 5 unit tests filling gaps: zero payer/payee/amount validation, exists-false, multiple IDs.

## Files Preserved (Not Deleted)

All `.bak` and `.disabled` files remain in place as historical records:
- `test/unit/AgreementEngine.t.sol.bak`
- `test/unit/EscrowEngine.t.sol.bak`
- `test/unit/SettlementEngine.t.sol.bak`
- `test/attack/phase_p_execution_authorization/Attack_NativeValueSubstitution.t.sol.disabled`
- `test/chaos/AdversarialChaos.t.sol.bak`
- `test/symbolic/AkmenaSymbolic.t.sol.bak`

## Evidence Labels

- **SOURCE-CONFIRMED:** All .bak/.disabled file contents read directly.
- **SOURCE-CONFIRMED:** Current contract APIs read from `src/autonomous/AgreementEngine.sol`, `src/economics/EscrowEngine.sol`, `src/economics/SettlementEngine.sol`, `src/authorization/AkmenaPolicyBoundary.sol`.
- **RUNTIME-PROVEN:** New tests pass (see commit).
- **STATIC-ANALYSIS:** Active coverage determined by grep + manual review of test files.
