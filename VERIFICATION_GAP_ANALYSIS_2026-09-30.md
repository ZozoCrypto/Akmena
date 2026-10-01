# What’s Left to Test — Full Verification Gap Analysis
**Date:** 2026-09-30 · **Branch:** `feature/model-d-operator-custody` @ `53ab335b`
**Purpose:** Complete inventory of everything untested, partially tested, or unverified before frontend work resumes.
**Standard:** Every claim below carries an evidence label. No assumptions disguised as facts.

---

## 1. Current suite ground truth

**RUNTIME-PROVEN (pending):** Full `forge test` at HEAD is running (started 18:51 MDT). Result to be filled in below.

- Recorded 2026-09-30: **820/820** (`d328ab16` era, after transient-proof rewrites).
- Alignment synthesis notes a later run showed **792/794** with 2 escrow failures — **now explained and resolved** (see §2).
- The 820/820 was an aggregate across runs, not one unrestricted current-HEAD run — the run in progress corrects this.

**Result:** `[PENDING — suite running]`

---

## 2. RESOLVED: AkmenaChaos EscrowFundingMismatch failures

**RUNTIME-PROVEN — 2026-09-30 (re-verified today):**

- The two failures (`testFuzz_CannotRefundUnlessSeller`, `testFuzz_CannotReleaseUnlessBuyer` reverting with `EscrowFundingMismatch()`) were a **test harness issue, not a real escrow bug**.
- Mechanism: the fuzzer could pick the escrow engine itself as buyer/seller; `createEscrow` then failed its balance-delta funding check because the engine was both payer and payee.
- Fixed by commit `e2ed6e6d` (ancestor of HEAD): two `vm.assume` lines excluding the engine as buyer/seller.
- Current: **5/5 PASS** at 1000 runs each; stress-tested at **5000 runs each** — all pass.
- The alignment synthesis claiming these "sit at HEAD" was stale. **Closed.**

---

## 3. R9 — Adversarial / stateful fuzzing: PARTIAL (Foundry-only)

**What exists (SOURCE-CONFIRMED on disk):**

| Artifact | Status |
|---|---|
| `test/invariant/ModelDBoundaryInvariantV2.t.sol` + handler (10 invariants) | RUNTIME-PROVEN per commit `bd033476` (500k calls, 10/10) |
| `test/invariant/ModelDBoundaryInvariantV3.t.sol` + handler (16 invariants, honest + malicious campaigns) | RUNTIME-PROVEN per commit `023eb7c7` (500k calls each) |
| `medusa.json` (repo root) | **DRAFT — self-labeled UNVERIFIED** |
| Medusa / Echidna binaries | **NOT INSTALLED** — neither is on this machine |

**The Medusa gap (NOT-ASSESSED):**
- `medusa.json` targets the **V2** handler; current is **V3** — config is stale even as a draft.
- The handlers use `vm.sign` / `vm.addr`, which Medusa 1.5.1 does not support — the config **cannot run as written**.
- No Echidna config exists at all.
- Elijah’s PC is the only Medusa-capable environment.

**Decision required (Elijah):**
- **Option A:** Accept Foundry-only for R9 (document the Medusa leg as waived with rationale).
- **Option B:** Commission a Medusa-specific handler rewrite (no `vm.sign`/`vm.addr`, pre-computed signatures) + validate `medusa.json` against an installed Medusa.
- Do not silently treat Foundry as satisfying the independent-fuzzer requirement.

---

## 4. R10 — Mutation testing (Gambit): PARTIAL (5/20)

**SOURCE-CONFIRMED on disk:**
- `/home/hatch/workspace/gambit_out/`: 20 deterministic mutants, **all in `src/authorization/AkmenaPolicyBoundary.sol`** (3× DeleteExpression, 1× Assignment, 9× IfStatement, 2× BinaryOp, 2× SwapArguments).
- Per memory record (only record — **no classification file exists on disk**): 5 representative mutants installed one at a time, each killed by `Governance_Phase7.t.sol` (5/5 sampled kill rate).
- **15 mutants unclassified.** No committed R10 report. Zero R10 mentions in any repo doc.
- No mutation of any other contract (Core, EscrowEngine, ExecutionAuthorization, PrivacyEngine).

**What’s left:**
1. Classify the remaining 15 mutants (kill/survive with justification) — or justify a sampling argument.
2. Write and commit the R10 report.
3. Decide whether other value-moving contracts need mutation (Core pause path, EscrowEngine funding check).

---

## 5. R11 — Halmos symbolic verification: PARTIAL (1 meaningful proof)

**SOURCE-CONFIRMED** in `test/symbolic/BoundarySymbolicR11.t.sol`:

| Property | Status |
|---|---|
| `check_PauseBlocksExecution` | Claimed PROVEN in commit `0f78f8ea`; **meaningful** (symbolic intent params, low-level call) |
| `check_ZeroOperatorReverts` | Claimed PROVEN; **vacuous** (zero operator reverts trivially) |
| `check_NonceTracking` | **PLACEHOLDER** — body is `assertTrue(nonce == nonce)` |

**Evidence caveat (DOCUMENTED):**
- `halmos` was **not installed** when the claims were recorded — no run logs exist on disk. The "PROVEN" labels rest on commit messages.
- Halmos 0.3.3 was installed today (2026-09-30) in this environment — re-verification is now possible and pending.

**What’s left:**
1. Re-run Halmos on `check_PauseBlocksExecution` and record actual output (confirm or retract PROVEN).
2. Write a real nonce-uniqueness property (the one that matters for replay protection). The V3 Foundry test `replayAlwaysReverts` covers this dynamically, but the symbolic proof is the R11 deliverable.
3. Decide whether additional critical paths need symbolic proofs (allowance pre-check, charge-before-pull ordering).

**Disabled symbolic tests:** `test/symbolic/AkmenaSymbolic.t.sol.bak` (pre-Model-D, superseded — no action).

---

## 6. R12 — Base Sepolia fork test: EXISTS, thin

**SOURCE-CONFIRMED:**
- `test/fork/ModelDBaseSepoliaFork.t.sol`: 4 tests (chain ID, real USDC deployed, full Model D settlement 10 USDC, pause blocks settlement).
- `REGRESSION_2026-09-30.md` records **4/4 PASS** at block 47517890.

**What’s left:**
1. Single data point — no re-runs recorded. Re-run to confirm reproducibility.
2. Coverage is narrow: no native-ETH path on fork, no malicious-token behavior on fork, no governance transitions on fork, no multi-operator isolation on fork.
3. Decide the fork campaign’s intended scope (smoke vs. full path coverage).

---

## 7. R13 — Frontend: BLOCKED (not a test gap — a provenance gap)

**SOURCE-CONFIRMED — still open:**
- `deployments/base-sepolia/deployment.json`: 4 contracts, no PrivacyEngine, **EIP-712 version `"1"`**; code (`AkmenaExecutionAuthorization.sol:66`) signs **`"2"`**. Any signer configured from this file produces **rejected signatures**.
- Frontend `privacyEngine` address `0x7e5095d10a4B71220938b816398918239981030a`: **zero on-chain code** on Base Sepolia and Base mainnet. Previous address has 1651 bytes matching the pre-fix fingerprint.
- ~36 contracts missing from deployment.json. Dated 2026-08-29.

**What’s left (before any frontend work):**
1. Decide: fresh deployment record vs. reconcile existing.
2. Regenerate deployment.json from actual deployments (or document it as historical).
3. Resolve the frontend privacyEngine address (remove dead reference, point at hardened build, or defer privacy).
4. EIP-712 version must match between config and code — currently a hard break.

---

## 8. R14 — Regression: INCOMPLETE

- The 800/800 (now 820/820) counts were aggregates, not one unrestricted current-HEAD run.
- The full-suite run in progress (§1) is the corrective evidence.
- **After it lands:** record exact command, seed, commit hash, and count. If green, R14 closes for this HEAD.

---

## 9. R15 — Independent review: NOT STARTED

- No bounty-style independent review commissioned.
- **Decision required:** scope and timing (pre- or post-frontend).

---

## 10. G-7 (governance productionization): OPEN

**SOURCE-CONFIRMED open items:**
1. Production timelock contract selection + parameters (delay).
2. Production multisig selection + key holders.
3. Pause guardian designation (Elijah may take it or name another).
4. Adapter-update monitoring + operator-notification path.
5. Incident-response runbook.

The Phase 7 mechanism (pauseGuardian, allowlistAdmin/emergencyAdmin split, timelock migration simulation) is **RUNTIME-PROVEN** (19/19 incl. OZ TimelockController simulation) — but the production *instantiation* is undecided. This is a decision + deployment gap, not a code gap.

---

## 11. Disabled / superseded tests: 6 files triaged

| File | Verdict |
|---|---|
| `test/attack/.../Attack_NativeValueSubstitution.t.sol.disabled` | **Needs verification** — the native-value-substitution attack is referenced in active tests (`Attack_ProductionExecutionSemantics`, `Attack_CriticalEconomicLimitBypass`), but equivalence with the disabled file’s coverage is **NOT-ASSESSED**. Either verify coverage or re-enable. |
| `test/chaos/AdversarialChaos.t.sol.bak` | Pre-Model-D; superseded by `AkmenaChaos.t.sol` (5/5). No action. |
| `test/symbolic/AkmenaSymbolic.t.sol.bak` | Pre-Model-D; superseded by `BoundarySymbolicR11.t.sol`. No action. |
| `test/unit/AgreementEngine.t.sol.bak` (18 tests) | **GAP** — no active `AgreementEngine.t.sol` exists; coverage via other files NOT-ASSESSED |
| `test/unit/EscrowEngine.t.sol.bak` (8 tests) | **GAP** — no active `EscrowEngine.t.sol`; escrow covered in attack/chaos/invariant tests but unit-level equivalence NOT-ASSESSED |
| `test/unit/SettlementEngine.t.sol.bak` (11 tests) | **GAP** — no active `SettlementEngine.t.sol`; equivalence NOT-ASSESSED |

**What’s left:** For the three `.bak` unit files + the `.disabled` attack file, either confirm current tests cover the same ground (with file/line references) or restore them. "It’s probably covered" is not evidence.

---

## 12. Privacy v2: real-proof e2e COMPUTE-BLOCKED

**Status:**
- Circuit compiles (5,313 constraints). Contract logic tested (11/11 + Grok invariants 2/2 + hazard pin 1/1).
- Trusted setup (`snarkjs groth16 setup`) ran **73 minutes** without completing in this VM, while contending with the test suite. Killed to prioritize the suite.
- The one-input nullifier hash mismatch (circuit `Poseidon(nullifier)` vs JS `Poseidon(nullifier, 0)`) remains unresolved — must be fixed before any e2e.

**What’s left:**
1. Fix nullifier hash parity (one-input Poseidon in JS).
2. Complete trusted setup on a faster machine (or accept a multi-hour run here).
3. Generate real proof → verify against generated `WithdrawVerifier.sol` → run full e2e matrix (double-spend, wrong recipient/relayer/fee, unknown root, wrong denomination, multi-leaf paths, capacity, reentrancy).
4. Correct the policy-bypass test to integrate with the actual `PolicyBoundary` (currently standalone, native ETH, amount == limit — proves nothing about integration).
5. **Decision:** association-set/ragequit vs. RAIL20 integration vs. defer privacy — unchanged, still Elijah’s call.

---

## 13. Prioritized action list

**P0 — correctness of the safety claim:**
1. [ ] Land the current full-suite run; record exact command/seed/commit/count (closes R14 for this HEAD).
2. [ ] Triage the 4 disabled test files (`.disabled` + 3 unit `.bak`) — verify coverage or restore.
3. [ ] Re-run Halmos on the pause proof; write the real nonce property (R11).

**P1 — campaign completeness:**
4. [ ] Classify remaining 15 Gambit mutants; commit R10 report (R10).
5. [ ] Elijah decides: Medusa rewrite vs. Foundry-only waiver (R9).
6. [ ] Re-run R12 fork test; decide fork scope (R12).
7. [ ] Commission or schedule R15.

**P2 — pre-frontend blockers:**
8. [ ] Reconcile deployment.json (EIP-712 v1/v2 is a hard break).
9. [ ] Resolve frontend privacyEngine dead address.
10. [ ] G-7 production instantiation decisions.

**P3 — privacy v2:**
11. [ ] Fix nullifier parity; complete setup + real-proof e2e on adequate hardware.
12. [ ] Correct policy-bypass integration test.
13. [ ] Privacy direction decision.

---

*Evidence labels: SOURCE-CONFIRMED / STATIC-ANALYSIS / RUNTIME-PROVEN / CHAIN-VERIFIED / DOCUMENTED / ASSUMPTION / NOT-ASSESSED — per project standard.*
