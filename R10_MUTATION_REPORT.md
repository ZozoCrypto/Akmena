# R10 Mutation Testing Report
**Date:** 2026-10-01 · **Contract:** `src/authorization/AkmenaPolicyBoundary.sol`
**Tool:** Gambit · **Mutants:** 20 deterministic · **Branch:** `feature/model-d-operator-custody`

## Summary

| # | Type | Location | Status | Killed By / Gap |
|---|------|----------|--------|-----------------|
| 1 | DeleteExpression | 139: executionAuthorization init | KILLED | Prior classification (governance tests) |
| 2 | Assignment | 261: isStandardDebit false→true | KILLED | Prior classification (governance tests) |
| 3 | IfStatement | 358: core.isPaused() → false | KILLED | Prior classification (governance tests) |
| 4 | IfStatement | 364: agent==0 → true | KILLED | Prior classification (governance tests) |
| 5 | IfStatement | 376: operator==0 → true | KILLED | Prior classification (governance tests) |
| 6 | IfStatement | 383: isNative → false | KILLED | Attack_ProductionExecutionSemantics (2 failures) |
| 7 | SwapArgs | 405: amount>0 → 0>amount | KILLED | ModelD_OperatorCustodySettlement (2 failures) |
| 8 | IfStatement | 411: target==asset check → false | SURVIVED | Zero-amount self-call not tested; amount>0 covered by defense-in-depth (line 432) |
| 9 | IfStatement | 439: maxSpendPerTx==0 → false | KILLED | AkmenaPolicyBoundary (1 failure) |
| 10 | IfStatement | 464: isNative&&msg.value==0 → false | SURVIVED | Zero-value native headroom path not covered |
| 11 | BinaryOp | 469: headroom `-` → `*` | SURVIVED | Zero-value native headroom calculation not covered |
| 12 | IfStatement | 470: amount>headroom → false | SURVIVED | Zero-value native headroom check not covered |
| 13 | DeleteExpression | 475: delete _verifyActiveEscrow | SURVIVED | No test sets `requireActiveEscrow=true` |
| 14 | IfStatement | 479: isNative → false (settlement) | KILLED | Attack_ProductionExecutionSemantics (2 failures) |
| 15 | IfStatement | 482: !success → true | KILLED | ModelD_OperatorCustodySettlement (3 failures) |
| 16 | IfStatement | 488: msg.value>0 → false | EQUIVALENT | Earlier NativeValueMismatch check guarantees `intent.amount == msg.value` |
| 17 | BinaryOp | 492: headroom `-` → `/` | SURVIVED | Native settlement headroom not covered |
| 18 | SwapArgs | 541: allowance check inverted | KILLED | ModelD_OperatorCustodySettlement (3 failures) |
| 19 | SwapArgs | 549: daily limit check inverted | KILLED | ModelD_OperatorCustodySettlement (3 failures) |
| 20 | DeleteExpression | 564: delete safeTransferFrom | KILLED | ModelD_OperatorCustodySettlement (3 failures) |

**Mutation Score:** 13 KILLED + 1 EQUIVALENT = 14/20 (70%) effective; 6 SURVIVED (30%)

## Detailed Analysis

### KILLED Mutants (13)

**Mutant 6** (IfStatement, line 383): `if (isNative)` → `if (false)`
- Skips native value validation (`msg.value != intent.value` check).
- Killed by: `Attack_ProductionExecutionSemantics.t.sol` — 2 tests fail with `NativeValueMismatch()` (expected, since the check is skipped, downstream behavior differs).

**Mutant 7** (SwapArguments, line 405): `intent.amount > 0` → `0 > intent.amount`
- The condition `0 > intent.amount` is always false (uint256). Skips StandardDebit admission check.
- Killed by: `ModelD_OperatorCustodySettlement.t.sol` — 2 tests fail (unadmitted tokens incorrectly allowed).

**Mutant 9** (IfStatement, line 439): `policy.maxSpendPerTransaction == 0` → `false`
- Skips the `UnauthorizedAgent` revert for unconfigured policies.
- Killed by: `AkmenaPolicyBoundary.t.sol` — 1 test fails.

**Mutant 14** (IfStatement, line 479): `if (isNative)` → `if (false)` (settlement branch)
- Native intents incorrectly routed to `_settleERC20`, which tries `IERC20(address(0))`.
- Killed by: `Attack_ProductionExecutionSemantics.t.sol` — 2 tests fail with `EvmError: Revert`.

**Mutant 15** (IfStatement, line 482): `if (!success)` → `if (true)`
- Always reverts after native call, even on success. Breaks all native executions.
- Killed by: `ModelD_OperatorCustodySettlement.t.sol` — 3 tests fail.

**Mutant 18** (SwapArguments, line 541): Allowance check inverted
- Original: `if (allowance < amount) revert InsufficientOperatorAllowance()`
- Mutant: `if (amount < allowance) revert ...` — reverts when allowance is sufficient.
- Killed by: `ModelD_OperatorCustodySettlement.t.sol` — 3 tests fail (including `test_AR3_AllowanceRevokedMidFlightRevertsCleanly` with wrong error).

**Mutant 19** (SwapArguments, line 549): Daily limit saturating logic inverted
- Original: `totalSpentToday >= dailyLimit ? 0 : dailyLimit - totalSpentToday`
- Mutant: `dailyLimit >= totalSpentToday ? 0 : ...` — headroom is 0 in normal case.
- Killed by: `ModelD_OperatorCustodySettlement.t.sol` — 3 tests fail with `PolicyExceeded()`.

**Mutant 20** (DeleteExpression, line 564): Delete `safeTransferFrom` (pull)
- Skips pulling funds from operator. Subsequent push fails with insufficient balance.
- Killed by: `ModelD_OperatorCustodySettlement.t.sol` — 3 tests fail with `ERC20InsufficientBalance`.

### SURVIVED Mutants (6) — Test Gaps

**Mutant 8** (IfStatement, line 411): `intent.target == intent.asset && !isEconomicAdapter` → `false`
- **Severity:** Low.
- **Analysis:** Skips the `EconomicAdapterNotAllowed` check for self-adapter calls. However, line 432 provides defense-in-depth: `if (intent.amount > 0 && intent.target == intent.asset) revert InvalidAdapter()`. For amount > 0, behavior is equivalent (both revert). For amount == 0, the mutant allows a zero-amount call to the token contract that would have reverted.
- **Gap:** No test exercises zero-amount self-adapter calls (`target == asset`, `amount == 0`).
- **Recommended test:** `test_ZeroAmountSelfAdapterReverts()` — attempt a zero-amount intent with `target == asset`, assert `EconomicAdapterNotAllowed()`.

**Mutant 10** (IfStatement, line 464): `isNative && msg.value == 0` → `false`
- **Severity:** Medium.
- **Analysis:** Skips the headroom check for zero-value native generic calls. An attacker could exceed daily limits via zero-value native calls (though no funds move, the policy accounting would be wrong).
- **Gap:** No test covers zero-value native execution with daily limit enforcement.
- **Recommended test:** `test_ZeroValueNativeRespectsDailyLimit()` — set a low daily limit, attempt zero-value native calls exceeding it, assert `PolicyExceeded()`.

**Mutant 11** (BinaryOp, line 469): `dailyLimit - totalSpentToday` → `dailyLimit * totalSpentToday`
- **Severity:** Medium.
- **Analysis:** Corrupts headroom calculation for zero-value native path. With `totalSpentToday=0`, headroom becomes 0 instead of `dailyLimit`, causing false `PolicyExceeded` reverts. With other values, headroom is wildly wrong.
- **Gap:** Zero-value native headroom calculation not tested.
- **Recommended test:** `test_ZeroValueNativeHeadroomCalculation()` — verify headroom is `dailyLimit - totalSpentToday` via zero-value native executions at various spent amounts.

**Mutant 12** (IfStatement, line 470): `intent.amount > headroom` → `false`
- **Severity:** Medium.
- **Analysis:** Skips the headroom enforcement for zero-value native calls. Allows exceeding daily limits.
- **Gap:** Same as mutant 10 — zero-value native path not covered.
- **Recommended test:** Same as mutant 10.

**Mutant 13** (DeleteExpression, line 475): Delete `_verifyActiveEscrow(policy, intent, agent)`
- **Severity:** High (if the feature is used).
- **Analysis:** The `_verifyActiveEscrow` function returns early unless `policy.requireActiveEscrow == true`. No test in the suite sets this flag, so the function is dead code in tests. Deleting the call is semantically different (would skip escrow verification if the flag were set), but no test exercises that path.
- **Gap:** The `requireActiveEscrow` policy feature has zero test coverage.
- **Recommended test:** `test_RequireActiveEscrowEnforced()` — set `requireActiveEscrow=true` on a policy, attempt execution without valid escrow proof, assert `InvalidTransientProof()`. Also test the happy path with valid proof.

**Mutant 17** (BinaryOp, line 492): `dailyLimit - totalSpentToday` → `dailyLimit / totalSpentToday`
- **Severity:** High.
- **Analysis:** Corrupts headroom calculation for native settlement with `msg.value > 0`. If `totalSpentToday == 0`, this causes a division-by-zero panic. Otherwise, headroom is completely wrong (e.g., `dailyLimit=1000, spent=100` → `10` instead of `900`).
- **Gap:** Native settlement headroom calculation not tested. The `ModelD_OperatorCustodySettlement.t.sol` focuses on ERC20, not native.
- **Recommended test:** `test_NativeSettlementHeadroomCalculation()` — perform native settlements with various `totalSpentToday` values, verify `PolicyExceeded` triggers at the correct threshold. Include a case with `totalSpentToday=0` to catch division-by-zero.

### EQUIVALENT Mutants (1)

**Mutant 16** (IfStatement, line 488): `msg.value > 0` → `false`
- **Analysis:** The code charges `policy.totalSpentToday += msg.value` in the `if` branch and `+= intent.amount` in the `else` branch. The earlier check at line 387-389 (`if (msg.value > 0 && intent.amount != msg.value) revert NativeValueMismatch()`) guarantees that when `msg.value > 0`, `intent.amount == msg.value`. Therefore both branches compute the same value, and the mutant is semantically equivalent.
- **Note:** This is a true equivalent, not a test gap. No test can kill it because the behavior is identical.

## Methodology

1. Mutants 1-5: Prior classification (KILLED by governance tests), taken as given.
2. Mutants 6-20: Empirical testing via targeted test files.
   - Applied mutant to `src/authorization/AkmenaPolicyBoundary.sol`
   - Ran the most relevant test file with `forge test --match-path`
   - Reverted immediately after each test
   - **Safety:** After a parent-agent warning about a mutant left applied, all subsequent tests used single-command apply-test-revert with verification.
3. SURVIVED mutants were analyzed for root cause (test gap vs. equivalent).

## Recommendations

1. **Immediate:** Add tests for the 6 survived mutants (see recommended tests above). Priority order: 17 (division by zero), 13 (escrow bypass), 10/11/12 (zero-value native), 8 (low severity).
2. **Coverage:** The zero-value native execution path and native settlement headroom need dedicated test coverage.
3. **Feature:** The `requireActiveEscrow` policy flag is untested — decide if it's a live feature (needs tests) or dead code (should be removed).
4. **Mutation score target:** With the recommended tests, achievable score is 19/20 (95%) + 1 equivalent = 100% effective.

## Files Changed

- None (analysis only). This report is the deliverable.

## Evidence Labels

- Mutant classifications 6-20: **RUNTIME-PROVEN** (empirical forge test runs)
- Mutants 1-5: **DOCUMENTED** (prior classification, not re-verified)
- Gap analyses: **STATIC-ANALYSIS** (code inspection)
- Mutant 16 equivalence: **STATIC-ANALYSIS** (verified by code path analysis)
