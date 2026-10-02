# Akmena Decision Packet
**Date:** 2026-10-02
**For:** Elijah
**Purpose:** Every checklist item blocked on your decision, in one place. Work through in a single pass.

---

## Decision 1: G-1 — Design Approval (Spec v1.2)

**What:** Sign off on the Model D (operator-retained custody) design spec v1.2.

**Evidence available:**
- Spec: `~/workspace/goals/akmena-red-team-security-verification/files/model-d-implementation-spec-v1.2.md`
- Traceability matrix: exists
- Adversarial review: ChatGPT reviewed v1.1, all points addressed in v1.2

**Your options:**
- [ ] **APPROVE** — Design is accepted, implementation can proceed to release
- [ ] **APPROVE WITH CHANGES** — Specify what needs to change
- [ ] **REJECT** — Design needs rework

---

## Decision 2: G-7 — Governance Migration (Critical Path)

This is the biggest blocker. Until G-7 executes, the deployer key is a single point of total control.

### 2A: Timelock Deployment
**What:** Deploy OZ `TimelockController` with 24h delay.

**Your options:**
- [ ] **DEPLOY** — I will prepare the deployment script for your review
- [ ] **DEFER** — Accept the risk of deployer-key control for now

### 2B: Safe Multisig Deployment
**What:** Deploy Safe (3-of-5) to hold `emergencyAdmin` (fast remove-only role).

**Currently designated:**
- Owner 1: Elijah (`0x2D4888499D765d387f9CbC48061b28CDe6bC2601`)

**You need to designate 4 additional owners:**
- Owner 2: _________________________
- Owner 3: _________________________
- Owner 4: _________________________
- Owner 5: _________________________

**Threshold:** 3-of-5 (recommended) or specify: _____

### 2C: Pause Guardian Designation
**What:** Designate who holds the pause guardian key (can pause immediately, cannot unpause).

**Your options:**
- [ ] **Elijah** (same address as above)
- [ ] **Another address:** _________________________
- [ ] **DEFER** — Deployer retains pause power for now

### 2D: Role Transfers
Once timelock + multisig exist:
- [ ] Transfer `emergencyAdmin` → Safe multisig
- [ ] Transfer `allowlistAdmin` → TimelockController
- [ ] Transfer `deployer` → TimelockController (via two-step: propose → timelock accepts)

**Note:** Deployer is the sole unpauser. If timelock holds deployer, unpausing takes 24h. Alternative: cold Safe as deployer.

**Your preference:**
- [ ] Timelock as deployer (24h unpause delay accepted)
- [ ] Cold Safe as deployer (faster unpause, still multisig)
- [ ] Defer deployer transfer

---

## Decision 3: G-4 — Admission Criteria Ratification

**What:** Ratify the §7.2 Standard-Debit admission criteria from spec v1.2.

**Evidence:** AKM token battery: 9/9 pass (exact transfer, amount-honest pull, allowance accounting, failure reverts, no sender hooks).

**Your options:**
- [ ] **RATIFY** — §7.2 criteria are accepted as the admission standard
- [ ] **RATIFY WITH CHANGES** — Specify modifications
- [ ] **REVIEW AKM FIRST** — You want to review the 9/9 battery before ratifying

---

## Decision 4: G-5 — Migration Posture (M-1)

**What:** Decide how to handle the 1 legacy boundary on Base Sepolia (`0xdC3fC3e840b14Ce345638549D0d4617b75cD89b9`).

**Finding:** V-9 resolved — the legacy contract cannot hold a self-adapter grant (feature didn't exist at deployment, no upgrade path).

**Your options:**
- [ ] **LEAVE AS-IS** — Legacy contract is inert, no action needed
- [ ] **MONITOR** — Watch `EconomicAdapterUpdated` events on new deployments
- [ ] **OTHER:** _________________________

---

## Decision 5: G-6 — Model C Timing

**What:** Decide when (if ever) to pursue Model C (pooled custody) as a separate organizational model.

**Your options:**
- [ ] **DEFER INDEFINITELY** — Model D only for now
- [ ] **EXPLORE LATER** — After mainnet launch and audit
- [ ] **OTHER:** _________________________

---

## Decision 6: S-8 — Independent Reviewer (R15)

**What:** Commission an independent reviewer for the R15 package.

**Package status:** Updated 2026-10-02 with:
- Medusa 100k native-path campaign (100,387 calls, 0 failures)
- Slither hardened-tree results
- GAP-1 through GAP-3 patches documented
- Full commit history through HEAD

**Your options:**
- [ ] **COMMISSION NOW** — Specify reviewer or bounty platform: _________________________
- [ ] **WAIT** — Until after invariant re-run completes and R10/R11 are done
- [ ] **DEFER** — R15 after mainnet soft-launch

---

## Decision 7: G-2/G-3 — Implementation & Release Acceptance

**What:** Accept the implementation and approve release (after all technical work completes).

**Status:** BLOCKED until:
- Invariant re-run completes (currently 4/17)
- R10 mutation re-run (Gambit unavailable — needs manual run)
- R11 Halmos re-verification (Halmos unavailable — needs manual run)

**No action needed yet** — this will be presented when technical work is done.

---

## Summary Checklist

| # | Decision | Status |
|---|----------|--------|
| 1 | G-1 Design approval | ☐ Pending |
| 2A | Timelock deployment | ☐ Pending |
| 2B | Safe owners (4 needed) | ☐ Pending |
| 2C | Pause guardian | ☐ Pending |
| 2D | Role transfer preference | ☐ Pending |
| 3 | G-4 Admission criteria | ☐ Pending |
| 4 | G-5 Migration posture | ☐ Pending |
| 5 | G-6 Model C timing | ☐ Pending |
| 6 | S-8 Reviewer commission | ☐ Pending |
| 7 | G-2/G-3 Release | ⏳ Blocked on technical work |

---

**How to respond:** Reply with your decisions by number (e.g., "1: APPROVE, 2A: DEPLOY, 2B: [addresses], 2C: Elijah, 2D: Cold Safe, 3: RATIFY, 4: LEAVE AS-IS, 5: DEFER, 6: WAIT"). Or work through them one at a time — your call.
