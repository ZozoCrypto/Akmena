# Akmena Mainnet-Readiness Checklist
**Version:** 1.0 — 2026-10-01
**Branch:** `feature/model-d-operator-custody`
**Purpose:** Single tracker for mainnet readiness. Every item carries Evidence, Exact revision, Status, and Approver.
**Authority:** Elijah retains approval over design, governance, risk acceptance, and release. Muse supplies technical evidence.

**Status values:** `COMPLETE` | `BLOCKED` | `NOT-APPLICABLE` | `NOT-ASSESSED`
**Approver values:** `ELIJAH` (requires his sign-off) | `MUSE` (technical evidence) | `REVIEWER` (independent)

---

## 1. Testing

*Principle: Combine unit, integration, property-based, and manual testing. Each method finds different classes of defects.*

| # | Item | Evidence | Exact Revision | Status | Approver |
|---|------|----------|----------------|--------|----------|
| T-1 | Unit test suite passes | Post-hardening (GAP-1 + GAP-3 + deployer transfer): 870 unit tests across 167 suites, 0 failures. (+18: 11 deployer transfer + 7 GAP-1 regression). Log: `test-logs/unit_final.log`. | `c4693934` | COMPLETE | MUSE |
| T-2 | Invariant test suite passes | G-2: 30 invariant tests across 17 suites, 0 failures. 51 min. Log: `/tmp/g2_invariant.log`. | `3c6b95f6` | COMPLETE | MUSE |
| T-3 | G-2 full-suite baseline at current HEAD | 873/873 (843+30). Vs 868/868 baseline: +5 = MedusaSettlementProofTest (new in 4498937a). Zero failures. ~78 min total. | `3c6b95f6` | COMPLETE | MUSE |
| T-4 | Seed sensitivity documented | R14 report notes 868/868 supersedes seed-sensitive 820/820 claim. Exact commands recorded. | `be75aa6e` | COMPLETE | MUSE |
| T-5 | Integration tests (cross-module) | Phase 3 adversarial settlement tests: AR-3, AR-4, AR-5 pass. SettlementInvariant 2/2, EconomicLayerInvariant 1/1. | `00428402` lineage | COMPLETE | MUSE |
| T-6 | Manual testing | Not conducted as a distinct phase. Adversarial manual PoCs exist (V-0, A-8 battery, gross-outflow). | — | NOT-ASSESSED | ELIJAH |
| T-7 | Fork tests (Base Sepolia) | R12: 6/6 pass (native, replay, over-limit, governance, fee-token) | `c886dbfc` | COMPLETE | MUSE |

**Notes:**
- T-1/T-2/T-3: G-2 re-run at current HEAD (`3c6b95f6`) is in progress. The 868/868 baseline was at `27167778`; two commits have landed since (R9 harness repair, G-7/R15 docs — both test/doc only, no `src/` changes, but G-2 requires confirmation).
- T-6: No formal manual testing phase. The adversarial PoCs are strong but were developer-driven, not structured manual test plans.

---

## 2. Security

*Principle: Review access control, external calls, and governance risks. A passing test suite does not eliminate attack paths.*

| # | Item | Evidence | Exact Revision | Status | Approver |
|---|------|----------|----------------|--------|----------|
| S-1 | Access control review | R2 (auth): All `onlyDeployer`, `allowlistAdmin`, `emergencyAdmin`, `pauseGuardian` paths tested. 19/19 governance transition tests pass. | `00428402` lineage | COMPLETE | MUSE |
| S-2 | External call safety | Reentrancy: `ReentrancyGuardTransient` on settlement; AR-5 reentrant adapter blocked. A-8 malicious-token battery: 2 critical findings (F-7 over-pull, silent-success) mitigated by admission, not code. | `00428402` lineage | COMPLETE | MUSE |
| S-3 | Slither static analysis | 154 contracts, 5 in-scope High/Medium triaged: H-1/H-2 SAFE-BY-DESIGN, M-1/M-3 FALSE POSITIVE, M-2 SAFE-BY-DESIGN. Zero require code changes. Report: `SLITHER_TRIAGE.md`. | 2026-10-01 | COMPLETE | MUSE |
| S-4 | Mutation testing (R10) | 20 mutants, 19 killed + 1 equivalent = 100% effective. 5 gap-fill tests added. | `85a08429`, `df849888` | COMPLETE | MUSE |
| S-5 | Fuzzing — Foundry invariants | 25/25 pass (R14). | `27167778` | COMPLETE | MUSE |
| S-6 | Fuzzing — Medusa (R9) | 11,114 calls, 0 failures, both security invariants pass. Harness repaired (`4498937a`). | `4498937a` | COMPLETE | MUSE |
| S-7 | R9 coverage gaps assessed | **100k campaign COMPLETE:** 100,022 calls, 1,056 branches, 62 corpus, 0 failures. Both invariants pass. 26/26 tests. 4m28s. Revision `5aa7f9f3`, config `medusa_100k.json` (8 workers, seqLen 200). Log: `/tmp/medusa_100k.log`. | `5aa7f9f3` | COMPLETE | MUSE |
| S-8 | Independent review (R15) | Package prepared (`R15_REVIEW_PACKAGE.md`). Reviewer NOT commissioned. | `3c6b95f6` | BLOCKED | ELIJAH |
| S-9 | Known findings triaged | V-0 closed by construction. N-7 resolved (Model D pull leg). A-8 F-7/F-8 documented with mitigations. **AR-13 disposition (Elijah 2026-10-01): CONFIRMED as real risk — deployer-compromise blast radius moves from boundary pool to operator allowances. Mitigation = G-7 timelocked/multisig adapter governance (pending execution). Not safe-by-design, not a false positive.** | Various | COMPLETE | MUSE |

**Notes:**
- S-3: The Slither high/medium findings need explicit triage (confirmed / safe-by-design / false positive / needs hardening) before this is COMPLETE.
- S-7: Elijah deferred the 100k+ campaign decision pending this checklist.
- S-9: AR-13 is the critical open item — deployer compromise blast radius is unmitigated until G-7 migration.

---

## 3. Formal Verification

*Principle: State exactly which properties were proved and what was outside the proof.*

| # | Item | Evidence | Exact Revision | Status | Approver |
|---|------|----------|----------------|--------|----------|
| F-1 | Symbolic properties proved (R11) | 13/13 Halmos properties pass. Covers: nonce replay protection, escrow caller gates, settlement headroom, governance non-admin reverts, pause enforcement. | `27167778` | COMPLETE | MUSE |
| F-2 | Proof scope documented | `R11_SYMBOLIC_REPORT.md`: Halmos 0.3.3, check-site limited. Cannot forge ECDSA signatures. Happy-path execution is concrete-test-only. | `27167778` | COMPLETE | MUSE |
| F-3 | Pause proof re-verified | Prior "PROVEN" label (commit message) superseded by actual Halmos run evidence (`check_PauseBlocksExecution`, 12 paths, 0.67s). | `27167778` | COMPLETE | MUSE |
| F-4 | Properties OUTSIDE proof scope | Documented: full settlement happy-path, cross-contract invariants, liveness properties. | `27167778` | COMPLETE | MUSE |

**Notes:**
- All R11 items are COMPLETE. The scope limitations are honest and documented, not gaps.

---

## 4. Governance

*Principle: Verify proposer, executor, administrator, and delay settings. Misconfigured roles can bypass safeguards or lock the protocol.*

| # | Item | Evidence | Exact Revision | Status | Approver |
|---|------|----------|----------------|--------|----------|
| G-1 | Design approval (spec v1.2) | Spec + traceability matrix + adversarial review exist. Written sign-off: NOT RECEIVED. | Spec v1.2 (2026-09-29) | BLOCKED | ELIJAH |
| G-2 | Implementation acceptance | Full-suite baseline in progress. 8 environmental exceptions documented. Adversarial reviews: no unresolved criticals/highs (AR-13 open, governance-related). | In progress | BLOCKED | ELIJAH |
| G-3 | Release approval | Deployment runbook: DRAFT IN PROGRESS (P3). Release approval: NOT RECEIVED. | — | BLOCKED | ELIJAH |
| G-4 | Admission criteria ratified | §7.2 criteria exist in spec. Ratification: NOT RECEIVED. Initial set (AKM 9/9 battery): NOT REVIEWED. | Spec v1.2 | BLOCKED | ELIJAH |
| G-5 | Migration posture (M-1) | V-9 inspection complete: 1 legacy boundary on Sepolia, self-adapter grants NOT-ASSESSED (cannot enumerate). M-1 decision: NOT RECEIVED. | 2026-10-01 | BLOCKED | ELIJAH |
| G-6 | Model C timing | No decision recorded. | — | NOT-ASSESSED | ELIJAH |
| G-7 | Governance migration executed | Brief delivered (`G7_GOVERNANCE_BRIEF.md`). Timelock: NOT DEPLOYED. Multisig: NOT DEPLOYED. Guardian: NOT DESIGNATED. Migration: NOT EXECUTED. Emergency drill: NOT CONDUCTED. | `3c6b95f6` | BLOCKED | ELIJAH |

**Notes:**
- G-7 is the critical path blocker. Until migration, the deployer key is a single point of total control with no timelock delay.

---

## 5. Multisig

*Principle: Verify owners and threshold on-chain, not just in deployment notes. The configured threshold determines who can authorize actions.*

| # | Item | Evidence | Exact Revision | Status | Approver |
|---|------|----------|----------------|--------|----------|
| M-1 | Multisig contract deployed | NOT DEPLOYED. Recommendation: Safe, 3-of-5. | — | BLOCKED | ELIJAH |
| M-2 | Owners verified on-chain | Cannot verify — contract does not exist. Elijah designated (`0x2D4888499D765d387f9CbC48061b28CDe6bC2601`). 4 additional holders: NOT DESIGNATED. | — | BLOCKED | ELIJAH |
| M-3 | Threshold verified on-chain | Cannot verify — contract does not exist. Recommended: 3-of-5. | — | BLOCKED | ELIJAH |
| M-4 | `emergencyAdmin` transferred to multisig | NOT EXECUTED. Current: `core.deployer()`. | Current source | BLOCKED | ELIJAH |

**Notes:**
- All multisig items are BLOCKED on Elijah designating holders and approving the Safe deployment.

---

## 6. Deployment

*Principle: Recompile and compare deployed bytecode against the exact source and settings. Source verification establishes what code is actually deployed.*

| # | Item | Evidence | Exact Revision | Status | Approver |
|---|------|----------|----------------|--------|----------|
| D-1 | Fresh deployment.json (EIP-712 v2) | DRAFT created: `deployments/deployment.json.DRAFT` with v2, governance placeholders, verification fields. Awaiting Elijah review. | 2026-10-01 | COMPLETE | MUSE |
| D-2 | Deployment runbook | DRAFT created: `DEPLOYMENT_RUNBOOK_DRAFT.md` covers preflight, deployment, verification, G-7 migration, rollback, approvals. Awaiting Elijah review. | 2026-10-01 | COMPLETE | MUSE |
| D-3 | Bytecode recompiled and compared | NOT PERFORMED. No fresh deployment exists to verify against. | — | NOT-ASSESSED | MUSE |
| D-4 | EIP-712 metadata correct | Code: `EIP712("AkmenaExecutionAuthorization", "2")`. Deployment.json: `"version": "1"`. MISMATCH CONFIRMED. | Current source vs `deployments/base-sepolia/deployment.json` | BLOCKED | MUSE |
| D-5 | PrivacyEngine address resolved | **DEFERRED by Elijah 2026-10-01.** Frontend references dead address `0x7e5095d10a4B71220938b816398918239981030a` (returns 0x on both Base chains). No funds at risk. Privacy v2 redesign is a separate future decision. | Memory 2026-09-30 | NOT-APPLICABLE | ELIJAH |
| D-6 | All contract addresses documented | DRAFT structure in `deployment.json.DRAFT` with placeholders for all 4 contracts. | 2026-10-01 | COMPLETE | MUSE |

**Notes:**
- D-4 is a hard blocker — the version mismatch is not a warning, it's a functional break.
- D-5 is Elijah's decision: redeploy now or defer privacy.

---

## 7. Recovery

*Principle: Prepare and rehearse incident response before launch. Immutable contracts may not be repairable in place.*

| # | Item | Evidence | Exact Revision | Status | Approver |
|---|------|----------|----------------|--------|----------|
| R-1 | Incident response runbook | DRAFT created: `INCIDENT_RESPONSE_RUNBOOK_DRAFT.md` covers P0-P3, containment, assessment, remediation, comms, F-8 warning. Awaiting review. | 2026-10-01 | COMPLETE | MUSE |
| R-2 | Emergency drill conducted | NOT CONDUCTED. Requires G-7 migration first (need timelock + multisig + guardian). | — | BLOCKED | ELIJAH |
| R-3 | Pause guardian designated and tested | NOT DESIGNATED. Role exists in code, `pauseGuardian` = `address(0)`. | Current source | BLOCKED | ELIJAH |
| R-4 | Adapter-update monitoring | `EconomicAdapterUpdated` event exists. Monitoring/alerting: NOT SPECIFIED. | Current source | NOT-ASSESSED | ELIJAH |
| R-5 | Migration contingency plan | DRAFT created: `MIGRATION_CONTINGENCY_PLAN_DRAFT.md` covers M-1/M-2/M-3, per-deployment checklist, stranded funds policy, rollback. Awaiting Elijah M-1 approval. | 2026-10-01 | COMPLETE | MUSE |

**Notes:**
- R-2 is the key rehearsal — it validates the entire governance chain works under pressure. Cannot be done until G-7 migration.
- R-4 is an assumption that needs explicit acceptance: operators are expected to monitor events and revoke allowances during timelock delays. This is social, not enforced.

---

## Summary Dashboard

| Area | Complete | Blocked | Not Assessed | Total |
|------|----------|---------|--------------|-------|
| 1. Testing | 3 | 3 | 1 | 7 |
| 2. Security | 5 | 3 | 1 | 9 |
| 3. Formal Verification | 4 | 0 | 0 | 4 |
| 4. Governance | 0 | 6 | 1 | 7 |
| 5. Multisig | 0 | 4 | 0 | 4 |
| 6. Deployment | 0 | 5 | 1 | 6 |
| 7. Recovery | 0 | 4 | 1 | 5 |
| **Total** | **12** | **25** | **5** | **42** |

### By Approver

| Approver | Blocked Items |
|----------|---------------|
| ELIJAH | 18 (gate approvals, governance decisions, holder designations, privacy decision, R15 commissioning, R9 campaign scope) |
| MUSE | 7 (G-2 baseline in progress, P3 drafts in progress, Slither triage, R9 estimate) |

### Critical Path (Must Resolve Before Mainnet)

1. **G-7 governance migration** — deployer is single point of total control until this is done
2. **D-4 EIP-712 mismatch** — functional break, not just a warning
3. **G-1/G-2/G-3 formal approvals** — gates are open, evidence is accumulating
4. **R-2 emergency drill** — validates the governance chain under pressure
5. **S-8 independent review** — R15 package ready, reviewer not commissioned

### Practical Launch Rule Check

- [ ] No unresolved critical security findings → **FAIL** (AR-13 open pending G-7)
- [ ] No unverified deployment configuration → **FAIL** (D-4 mismatch, no fresh deployment)
- [ ] No unassigned privileged roles → **FAIL** (guardian not designated, multisig not deployed)
- [ ] No missing formal gate approvals → **FAIL** (all 7 gates open)

**Verdict: NOT READY FOR MAINNET.** The checklist is functioning as intended — it surfaces exactly what remains.

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-10-01 | Initial checklist. Populated from R0-R15 evidence, G-7 brief, V-9 inspection, and research report. |
