# Akmena — Next-Phase Research and Readiness Assessment

**Date:** 2026-10-01/02
**Inspector:** Muse (main agent + 5 workstream subagents)
**Repository:** `/home/hatch/workspace/akmena-v260`
**Branch:** `feature/model-d-operator-custody` (local-only, unpushed)
**HEAD at assessment:** `a988033d` ("G-7 brief: 24h timelock, Safe/guardian placeholders")

**Authorization:** Research, inspection, and planning only. No deploys, migrations, role transfers, fund movements, or live-chain state changes. No production code changes without presented proposal + explicit approval.

---

## 1. Executive Summary

Akmena's settlement-layer security evidence is strong for the paths tested, but **the evidence package has decayed**: the GAP-1 production patch landed after all major fuzz, mutation, and formal campaigns completed, and several of those campaigns had structural gaps (vacuous properties, an unfuzzed native path, a lost Medusa log) that predate the patch. The single most important governance discovery is that **the deployer role is immutable and can never be disempowered** — three repository documents currently make claims about post-G-7 deployer disempowerment that are impossible, and the deployer key must be treated as a permanent privileged key with a cold-storage plan.

**Current posture: NOT READY FOR MAINNET.** All seven gates remain formally open. The path to readiness is concrete and bounded: re-run three stale campaigns at HEAD, remediate documented test-quality and documentation gaps, correct the governance drafts, obtain ~8 Elijah decisions (several with definitive options below), execute the rehearsal plan, then commission R15.

**Positive closures since last checkpoint:**
- GAP-1: independently verified patched (7/7 assertion suite; pre-patch fails exactly as predicted, post-patch passes).
- V-9: conclusively resolved by bytecode analysis — the legacy contract predates the adapter feature and *cannot* hold self-adapter grants.
- R12 fork tests: re-verified 15/15 at HEAD.
- R14 unit: 852/852 valid at HEAD (src/test byte-identical to tested revision).

---

## 2. Exact Repository and Test-Evidence Baseline

### Repository baseline (SOURCE-CONFIRMED)

| Item | Value |
|------|-------|
| Branch | `feature/model-d-operator-custody` |
| HEAD | `a988033d` |
| HEAD matches reported `c58c9876` | No — HEAD advanced by one docs-only commit (`a988033d`: G-7 brief 24h update). src/test byte-identical between `308d6ab8` → `a988033d` |
| Working tree | Clean (tracked); untracked scratch/docs files preserved per standing constraint |
| Commits after reported HEAD | None beyond `a988033d` (docs only) |
| Tags on this branch | None (v2.x tags are ancestors from `v2-implementation`) |
| Push state | Local-only, unpushed |

### GAP-1 commit chain (SOURCE-CONFIRMED)

| Commit | Content |
|--------|---------|
| `3e02c3ad` | GAP-1 production patch (src only, 24 lines, `AkmenaPolicyBoundary.sol`) |
| `968cc8fb` | 2 test file updates for hardened semantics |
| `308d6ab8` | 9 test updates (5 files) |
| `c58c9876` | Checklist update (docs) |
| `a988033d` | G-7 brief 24h timelock update (docs) — current HEAD |

### Test-evidence × revision matrix

| Campaign | Tested rev | Result | vs HEAD | Verdict |
|----------|-----------|--------|---------|---------|
| R14 unit | `308d6ab8` | 852/852, 166 suites | src/test identical | **VALID at HEAD** (SOURCE-CONFIRMED) |
| R14 invariant (G-2 leg) | `3c6b95f6` | 30/30, 17 suites | Pre-GAP-1 | **STALE — re-run needed** |
| R9 Medusa 100k | `5aa7f9f3` | 100,022 calls, 0 failures | Pre-GAP-1; log lost | **STALE — re-run needed** |
| R10 mutation | `85a08429` | 20 mutants, 100% effective | Pre-GAP-1; mutants #10-12 targeted deleted lines | **STALE — re-measure needed** |
| R11 Halmos | `27167778` | 13/13 | Pre-GAP-1; properties vacuous | **STALE + VACUOUS — rewrite needed** |
| R12 fork | `a988033d` | 15/15 | HEAD | **VALID** (RUNTIME-PROVEN, re-run at HEAD) |
| GAP-1 independent verify | `a988033d` vs `3e02c3ad^` | 7/7 post-patch; 2 fail pre-patch as predicted | HEAD | **VALID** (RUNTIME-PROVEN) |
| R13 SDK (TS) | `a988033d` | 29/29 | HEAD | VALID (client-binding, not adversarial) |
| R13 SDK (Python) | — | Not run | — | **NOT-ASSESSED** |

---

## 3. Gate-by-Gate Checklist (updated)

| Gate | Status | Evidence | Blockers |
|------|--------|----------|----------|
| G-1 Design approval | OPEN | Model D approved; spec v1.2 | — |
| G-2 Full regression baseline | **OPEN** | Unit 852/852 valid at HEAD; invariant 30/30 stale (pre-GAP-1) | Re-run invariant suite at HEAD (~51 min) |
| G-3 Testnet fork | **CLOSED-TECHNICALLY** | R12 15/15 at HEAD | Formal sign-off pending |
| G-4 Allowlist owner | **DECIDED** | Elijah designated (0x2D4888499D765d387f9CbC48061b28CDe6bC2601) | Effective at G-7 migration |
| G-5 R9/R10/R11 refresh | **OPEN** | All three stale post-GAP-1 | Re-run Medusa, re-measure mutation, rewrite R11 properties |
| G-6 Deployment rehearsal | **OPEN** | Runbook drafts exist with stale names + false claims | Correct drafts; execute R-0/R-1 rehearsals |
| G-7 Governance migration | **OPEN** | 24h decided; Safe/guardian unassigned; **immutable deployer discovered** | 8 Elijah decisions (§8); role designations; rehearsal |

---

## 4. Finding-by-Finding Gap Analysis

### GAP-1 — Native zero-value policy DoS
- **Classification:** Confirmed vulnerability → **PATCHED** (RUNTIME-PROVEN)
- **Affected code:** `AkmenaPolicyBoundary.sol:459-500` (`executeAuthorizedAgentCall`, native branch)
- **Threat:** Authorized agent submits `msg.value == 0` intents with large `intent.amount`; pre-patch code charged `intent.amount` to `totalSpentToday`, consuming the full daily limit at gas cost only.
- **Severity (was):** Medium — insider/compromised-agent required, DoS only, 24h self-healing.
- **Evidence:** Independent 7-test assertion suite (`scratch-poc/GAP1_IndependentVerify.t.sol`): pre-patch, 10 spam intents → `totalSpentToday = 1000 ether` (limit consumed, zero funds moved); post-patch, 7/7 pass — spam leaves spend at 0, value-carrying native charges exactly `msg.value`, over-limit reverts `PolicyExceeded`, mismatch reverts `NativeValueMismatch`.
- **Patch completeness:** 24 lines, one file. Full inventory of `totalSpentToday` charge sites confirms no bypass path: native-with-value charges `msg.value` (lines 491/496), ERC20 charges `intent.amount` (551/560), zero-value paths charge nothing.
- **Recommended action:** Promote the 7-test suite to `test/attack/` as permanent regression (needs Elijah approval per §8).

### GAP-2 — Native path skips adapter allowlist
- **Classification:** Intentional design with **UNDOCUMENTED** residual risk (DOC-1)
- **Affected code:** `AkmenaPolicyBoundary.sol:381` — `isEconomicAdapter = !isNative && ...`; allowlist gates sit inside the ERC20 branch only.
- **Threat:** Agent's own ETH can call any target. Fund theft impossible by construction (only `msg.value` moves; boundary holds no native balance). Residual risk is **identity**: calls execute as `msg.sender == boundary`.
- **Severity:** Low.
- **Evidence:** RUNTIME-PROVEN — native intent to non-allowlisted target succeeds with `lastCaller == boundary`.
- **Recommended action:** Add NatSpec at line 381 (why native skips: agent's own ETH, boundary never holds native, policy bounds apply) + threat-model entry warning integrators never to trust `msg.sender == boundary` alone.

### GAP-3 — Zero-amount ERC20 skips allowlist (confused deputy)
- **Classification:** Intentional design with **UNDOCUMENTED** residual risk (DOC-1)
- **Affected code:** `_settleERC20` lines 528-539: `intent.amount == 0` → plain `target.call(payload)`, no allowlist, no Standard-Debit, no charge.
- **Threat (concrete):** Authorized agent gets the boundary to invoke arbitrary functions on arbitrary contracts as the boundary's identity. **Realistic integration assumption required:** some contract must treat a call from the boundary address as authorization. Repo-wide search found **none in-repo** (no `onlyBoundary` checks, no boundary-trusting adapters) — the deputy is **latent**, materializing only if a future/off-repo integration allowlists the boundary as a trusted executor (e.g., marketplace accepting boundary-originated orders).
- **Why "no funds move" is insufficient:** Deputy power isn't limited to fund movement — registry writes, attestations, votes, order placement on trusting protocols are in scope *if* such trust exists.
- **Severity:** Low (no in-repo target, no fund movement) but real and permanent.
- **Evidence:** RUNTIME-PROVEN — test asserts `recorder.lastCaller() == address(boundary)`.
- **Recommended action (needs Elijah decision):** (a) Constrain zero-amount targets to registered proof modules/adapters (the intent already carries `proofModuleKey`; `core.getModule()` provides a principled registry), or (b) accept-and-document with integrator warning. See §8.

### GAP-4 — ERC777 hooks
- **Classification:** **Confirmed non-issue** (by mechanism + genuine adjacent evidence); dedicated test is vacuous.
- **Affected code:** `_settleERC20` pull/push (`safeTransferFrom`/`safeTransfer`).
- **Evidence:** `nonReentrant` (EIP-1153 transient) blocks reentry on the same entrypoint. `Attack_SmartAgentReentrancy.t.sol` genuinely attempts reentry and proves it's blocked. Standard-Debit admission gates token semantics.
- **Test gap:** `test_GAP4_ERC777HookCannotReenter` never fires a hook (mock's `hookTarget` unset) and never attempts reentry — its name claims proof it doesn't provide.
- **Recommended action:** Strengthen the test to actually fire a hook that calls back into the boundary and assert the revert, or delete it in favor of the battery test.

### Test-quality findings
- **TQ-1:** `SecurityGapTest.test_GAP1_ZeroValueIntentFillsDailyLimit` reads the wrong struct field — destructures field index 3 (`lastResetTimestamp`) as `totalSpentToday` (struct order at lines 18-24). Log-only, so it passes while printing meaningless evidence.
- **TQ-2:** Gap PoC tests are observational (`try/catch` + `emit log`), not regression. The 7-test assertion suite should replace GAP-1 coverage.

### Documentation finding
- **DOC-1:** Commit `3e02c3ad`'s message claims GAP-2/GAP-3 "documented as intentional." Repo-wide grep finds **zero** occurrences of "GAP-2"/"GAP-3" in src NatSpec, docs, or checklist. The rationale exists only in a commit message. Documentation is the approval gate for closing these as intentional.

---

## 5. Prioritized Next-Step Plan

### Phase 1 — Evidence refresh (technical, no decisions needed)
| # | Action | Acceptance | Effort |
|---|--------|-----------|--------|
| 1 | Re-run Foundry invariant suite at HEAD | Green, log saved durably (not /tmp) | ~51 min |
| 2 | Re-run Medusa 100k at HEAD | 0 failures, log archived in repo | ~5 min wall |
| 3 | Re-run R10 Gambit mutation at HEAD | New report; line numbers match current source | ~2-4 h |
| 4 | Fix 2 stale R11 properties (GAP-1-consistent); re-verify with Halmos | 13/13 or documented 11/13 | ~1 day |
| 5 | Update checklist S-4, S-6/S-7, F-1/F-2, T-7 to post-patch revisions | No stale revision references | ~2 h |
| 6 | Rewrite R15 package (14 corrections) | Reviewer-ready | ~1 day |
| 7 | Correct governance drafts (function names, 48h→24h, remove false claims) | Executable as written | ~4 h |

### Phase 2 — Test/doc hardening (needs Elijah approval on scope)
| # | Action | Depends on |
|---|--------|-----------|
| 8 | Promote GAP-1 7-test suite to `test/attack/` | D-B2 |
| 9 | Fix/replace vacuous GAP-4 test; fix TQ-1 wrong-field read | D-B3 |
| 10 | Add NatSpec for GAP-2/GAP-3 intentional-design rationale | D-B4 |
| 11 | GAP-3: implement zero-amount target constraint OR document acceptance | D-B1 |
| 12 | Mark `DeployAkmena.s.sol` deprecated/not-for-launch | D-C4 |

### Phase 3 — Governance (needs Elijah decisions + designations)
| # | Action | Depends on |
|---|--------|-----------|
| 13 | Resolve immutable-deployer question | D-D1 |
| 14 | Designate 4 Safe owners + guardian key holder | D-D2, D-D3 |
| 15 | Confirm 24h final; correct all 48h stales | D-D4 |
| 16 | Escrow-pause gap: accept or authorize code change | D-D6 |
| 17 | Execute R-0 rehearsal (local Anvil fork) | 13-16 |
| 18 | Execute R-1 rehearsal (Base Sepolia, ~2 days wall-clock) | 17 |

### Phase 4 — Independent review
| # | Action | Depends on |
|---|--------|-----------|
| 19 | Freeze RC tag (e.g., `rc-v2.6.0-r15`); pin toolchain | 1-6 |
| 20 | Push approval (branch is local-only) | Elijah |
| 21 | Commission R15 reviewer | 19-20, budget approval |

**Estimated timeline:** Phases 1-2: 1-2 weeks. Phase 3: 1-2 weeks + R-1 wall-clock. Phase 4: 7-9 weeks from commissioning to final report (ESTIMATE).

---

## 6. Governance and Operational Rehearsal Plan

### Role power matrix (SOURCE-CONFIRMED)

| Role | Holder (interim → target) | Powers |
|------|--------------------------|--------|
| `deployer` (immutable) | deployer EOA → **cannot transfer** | `setPaused(true/false)` (sole unpauser, forever), `setPauseGuardian`, `registerModule`, `setModuleStatus` |
| `allowlistAdmin` | deployer → timelock (24h) | `setEconomicAdapter` (add+remove), `setStandardDebit` (add+remove), `setAllowlistAdmin` |
| `emergencyAdmin` | deployer → Safe 3-of-5 | `emergencyRemoveEconomicAdapter` (remove only), `emergencyRemoveStandardDebit` (remove only), `setEmergencyAdmin` |
| `pauseGuardian` | unset → operational key | `setPaused(true)` only. Cannot unpause, cannot touch roles. |

### Critical findings
1. **Immutable deployer (CRITICAL):** `address public immutable deployer` (`AkmenaCore.sol:19`); no transfer function exists in `src/`. Three repo documents make impossible claims: NatSpec "unpause becomes the timelock after G-7"; brief §7 step 6 "deployer can no longer pause"; runbook §3.4 "unpause via timelock if migrated". Post-G-7, the deployer EOA permanently retains: sole unpause, pause, guardian rotation/disabling, module registry (live DoS over escrow-gated policies). AR-13 is only **partially** mitigated.
2. **Escrow not paused:** `releaseEscrow`/`refundEscrow` don't check `isPaused()` — pause halts settlements only, not escrow lifecycle. Containment planning must scope accordingly.
3. **Single-step transfers:** No propose/accept on any role transfer. Fat-finger to a wrong-but-valid address is unrecoverable for admin roles (guardian recoverable via deployer).
4. **Safe 2-of-5 = governance freeze:** Below threshold, no on-chain recovery (with `admin=address(0)` timelock, proposer roles can never be re-granted). Procedural mitigation only.
5. **Runbook stale names:** `transferAllowlistAdmin` → `setAllowlistAdmin`; `transferEmergencyAdmin` → `setEmergencyAdmin`; `emergencyRemoveAdapter` → `emergencyRemoveEconomicAdapter`; `core.paused()` → `core.isPaused()`; Safe cannot call `setPaused` (reverts).

### Rehearsal plan
- **R-0 (local Anvil fork, `vm.warp`):** Deploy core + boundary + OZ TimelockController(24h, proposers=[safe], executors=[safe], admin=address(0)) + Safe stand-in. Transfer roles; verification ceremony (timelock schedule+cancel no-op, Safe 0-value self-call, guardian pause → deployer unpause). Negative tests (deployer reverts on adapter ops, guardian can't unpause). Pause drill (confirm settlements halt, escrow continues). Recovery drill (schedule malicious add → cancel within delay; schedule legitimate → execute → emergency remove). Retained-powers drill (confirm deployer can still rotate guardian — EXPECTED).
- **R-1 (Base Sepolia, real 24h wall-clock):** Same with real Safe UI (5 owners coordinate), real guardian hardware key. ~2 days for schedule/cancel/execute cycle. Record all tx hashes.
- **R-2 (mainnet ceremony):** After R-1 sign-off. Preflight → deploy → verify bytecode → set guardian → transfer roles → verification ceremony → shortened drill → record in `deployment.json` (final).
- **Tabletop (no chain):** Safe 2-of-5 (governance freeze → key-management requirements); deployer key lost while paused (permanent brick → "never pause without deployer-key availability confirmed"); guardian compromised (deployer rotates; DoS only).

---

## 7. R15 Review-Readiness Assessment

**Verdict:** Package is stale in material ways; must be revised before reaching any reviewer.

**14 stale statements** (full table in workstream report): commit table ends at `4498937a` (6 commits since, including GAP-1 patch); "868/868" superseded twice; "R9: 1043 calls, not run" → 100k complete; fuzz covers pre-patch code and is ERC20-only (native path unfuzzed); Medusa log lost; R10 "100%" rests on kill tests asserting pre-GAP-1 behavior; 48h assumed (24h decided); native path out of scope (must be in); G-7 brief 24h/48h inconsistent; GAP-1..4/Slither triage/EIP-712 fork test missing.

**Evidence quality issues to disclose to reviewer:**
- Medusa `invariant_conservation` is conditionally vacuous (returns true in non-honest token modes).
- All 5 Halmos `executeAuthorizedAgentCall` properties are vacuous (symbolic signatures always fail; they prove "invalid signatures revert," not "the gate blocks valid executions").
- Native settlement path is fuzzed by nothing (all handlers hardcode `value: 0`) — largest unfuzzed production path, and the one GAP-1 touched.
- EIP-712 fork test deploys fresh contracts — proves the *source* uses v2, not the on-chain Sepolia bytecode.

**15 specific auditor questions prepared** (native three-way consistency, charge-before-pull rollback, ERC-1271 vs EOA fidelity, self-adapter guard completeness, concurrent-intent allowance race, transient lock on Cancun EVM, day-boundary manipulation, §7.2 as process-not-code, pause/unpause deadlock, intent-submission griefing, GAP-3 concrete deputy, fee-on-transfer exactness, v1→v2 transition, gas griefing, AkmenaCore reachability). Full text in workstream report.

**Effort estimate (ESTIMATE):** ~1,500 in-scope LOC. 3–5.5 person-weeks; 5-week engagement reasonable. 7–9 weeks commissioning decision to final report. Dependencies: frozen RC tag, revised package, repo access, toolchain pins, 24h technical contact, Base Sepolia RPC.

---

## 8. Decisions Requiring Elijah's Approval

### D-B1 — GAP-3 confused-deputy disposition
- **(a)** Implement zero-amount target allowlist (registered proof modules / adapters only). Preserves stated use case, closes arbitrary-target deputy. Requires production code change → R9-gate treatment.
- **(b)** Accept and document: add NatSpec + threat-model integrator warning. No code change.
- **(c)** Defer to R15: ask the auditor to assess.

### D-B2 — GAP-1 regression suite
- **(a)** Promote `scratch-poc/GAP1_IndependentVerify.t.sol` (7 tests) to `test/attack/`. Recommended.
- **(b)** Leave in scratch-poc.

### D-B3 — Test-quality fixes
- **(a)** Fix vacuous GAP-4 test (real hook callback) + fix TQ-1 wrong-field read. Recommended.
- **(b)** Delete the vacuous GAP-4 test, rely on battery test.
- **(c)** Leave as-is.

### D-B4 — GAP-2/GAP-3 documentation
- **(a)** Add NatSpec + threat-model entries, then close as "intentional with documented residual risk." Recommended.
- **(b)** Leave undocumented (not recommended — DOC-1).

### D-C1 — Medusa re-run scope
- **(a)** Full 100k re-run at HEAD (~5 min wall). Recommended.
- **(b)** Extended 11k only.
- **(c)** Accept staleness with documented deviation.

### D-C2 — Stale R11 properties
- **(a)** Rewrite GAP-1-consistent (+ optionally strengthen vacuous `!success` properties with mock ERC-1271 agent).
- **(b)** Delete the two stale ones, keep 11/13.

### D-C3 — Native fuzz gap
- **(a)** Add native settlement to a Foundry fuzz handler before R15. Recommended (largest unfuzzed path).
- **(b)** Document as accepted gap for the reviewer to probe.

### D-C4 — `DeployAkmena.s.sol` (deploys full suite incl. deferred PrivacyEngine)
- **(a)** Mark deprecated/not-for-launch. Recommended.
- **(b)** Leave as-is.

### D-C5 — R13 scope for R15
- Is SDK adversarial testing / TS↔contract EIP-712 parity in scope for the auditor, or deferred?

### D-D1 — Immutable deployer (MOST CONSEQUENTIAL)
- **(a)** Accept permanent deployer key: document as cold-storage "protocol steward," write unpause-availability procedure, correct all docs claiming disempowerment. No code change.
- **(b)** Authorize production code change making the deployer role transferable (two-step propose/accept). Design change → R9-gate treatment, implementation, tests, re-verification.
- **(c)** Deploy with timelock as deployer. NOT RECOMMENDED (pause would inherit 24h delay).
- **(d)** Deploy with a cold Safe as deployer. Privileged key remains, but multisig-held.

### D-D2 — Designate 4 additional Safe owners (currently `TO_BE_DESIGNATED`)

### D-D3 — Designate pause guardian key holder (currently `TO_BE_DESIGNATED`)

### D-D4 — Confirm 24h timelock final; authorize correcting all 48h stales

### D-D5 — `AkmenaTimelock`/`AkmenaGovernor` dead code: delete or mark deprecated? (Recommend delete.)

### D-D6 — Escrow-pause gap
- **(a)** Accept as documented behavior (pause = settlement halt, not full freeze).
- **(b)** Authorize code change adding `isPaused` checks to `EscrowEngine`. Design change → R9-gate treatment.

### D-D7 — Authorize correction of draft runbooks (stale names, false claims) or assign to numbered brief

### D-D8 — Rehearsal schedule: approve R-0 → R-1 (Sepolia, ~2 days) → R-2 sequencing

### D-F1 — R15: reviewer budget, 5-week timeline, NDA/90-day embargo, RC-tag push approval

---

## 9. Actions NOT Performed

- No contracts deployed; no transactions submitted; no roles transferred; no live-chain state changed.
- No production code changes (inspection only; the GAP-1 patch predates this assignment).
- No commits, pushes, merges, tags, amends, or rebases (except the pre-existing `a988033d` docs commit noted in §2).
- No auditor contacted; no funds committed or moved.
- No test suites re-run (except R12 fork at HEAD by Workstream C, and the pre-existing 852/852).
- Halmos not installed — R11 not re-executed. Python SDK tests not run. Medusa not re-run.
- GAP-3 proof-module allowlist not implemented (presented as D-B1).
- No credentials, keys, or secrets accessed, stored, or transmitted.

---

## Evidence Labels Used

- **SOURCE-CONFIRMED:** verified in repository source at stated commit.
- **RUNTIME-PROVEN:** observed from actual test execution with stated command/revision.
- **ASSUMPTION:** stated as assumption where made.
- **NOT-ASSESSED:** explicitly not evaluated.
- **ESTIMATE:** projections, not quotes (used for auditor effort/timeline).

## Key File Locations

| Item | Location |
|------|----------|
| This assessment | `NEXT_PHASE_READINESS_ASSESSMENT.md` |
| GAP-1 independent verify suite | `scratch-poc/GAP1_IndependentVerify.t.sol` |
| Gap tests | `test/attack/NativeGapTest.t.sol`, `test/attack/SecurityGapTest.t.sol` |
| Production patch | `src/authorization/AkmenaPolicyBoundary.sol` (commit `3e02c3ad`) |
| G-7 brief | `G7_GOVERNANCE_BRIEF.md` |
| R15 package (stale) | `R15_REVIEW_PACKAGE.md` |
| R15 readiness detail | Workstream F report (subagent) |
| Checklist | `MAINNET_READINESS_CHECKLIST.md` |
| Runbook drafts | `DEPLOYMENT_RUNBOOK_DRAFT.md`, `INCIDENT_RESPONSE_RUNBOOK_DRAFT.md`, `MIGRATION_CONTINGENCY_PLAN_DRAFT.md` |
