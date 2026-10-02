# Akmena Decision Packet
**Date:** 2026-10-02
**For:** Elijah
**Purpose:** Every checklist item blocked on your decision, in one place. Work through in a single pass.
**Status:** DECIDED 2026-10-02 — see decisions below each item.

---

## Decision 1: G-1 — Design Approval (Spec v1.2)

**DECIDED: ✅ APPROVE** — Model D v1.2 design accepted.

**What:** Sign off on the Model D (operator-retained custody) design spec v1.2.

**Evidence available:**
- Spec: `~/workspace/goals/akmena-red-team-security-verification/files/model-d-implementation-spec-v1.2.md`
- Traceability matrix: exists
- Adversarial review: ChatGPT reviewed v1.1, all points addressed in v1.2

---

## Decision 2: G-7 — Governance Migration (Critical Path)

### 2A: Timelock Deployment
**DECIDED: ✅ DEPLOY** — 24h OZ TimelockController.

### 2B: Safe Multisig Deployment
**DECIDED: ✅ 2-of-3 Safe** (not 3-of-5 — do not block on finding 5 owners).

**Currently designated:**
- Owner 1: Elijah (`0x2D4888499D765d387f9CbC48061b28CDe6bC2601`)
- Owner 2: ☐ **STILL NEEDED** — Elijah to designate
- Owner 3: ☐ **STILL NEEDED** — Elijah to designate

**Threshold:** 2-of-3

### 2C: Pause Guardian Designation
**DECIDED: ✅ Separate pause-only guardian** (distinct from Elijah and deployer).

- Address: ☐ **STILL NEEDED** — Elijah to designate

### 2D: Role Transfers
**DECIDED: ✅ Deploy from current key → transfer ownership to timelock → Safe owns timelock.**

Governance chain:
```
Safe (2-of-3)
  └── owns TimelockController (24h)
        └── owns AkmenaCore (deployer)
              ├── allowlistAdmin → timelock
              ├── emergencyAdmin → Safe (direct, for fast removal)
              └── pauseGuardian → separate address
```

**Note:** Deployer is the sole unpauser. Timelock as deployer means 24h unpause delay — accepted per this decision.

---

## Decision 3: G-4 — Admission Criteria Ratification

**DECIDED: ✅ RATIFY** — §7.2 criteria accepted. **Privacy pool explicitly out of scope** for admission.

**Evidence:** AKM token battery: 9/9 pass.

---

## Decision 4: G-5 — Migration Posture (M-1)

**DECIDED: ✅ ABANDON** — Legacy Sepolia contracts abandoned. Old addresses to be marked DEPRECATED in docs. Use fresh deployments for new tests.

**Affected:** `0xdC3fC3e840b14Ce345638549D0d4617b75cD89b9` (legacy boundary)

---

## Decision 5: G-6 — Model C Timing

**DECIDED: ✅ FROZEN** — Model C dropped from launch scope. Removed once Model D tests pass.

---

## Decision 6: S-8 — Independent Reviewer (R15)

**DECIDED: ✅ WAIT** — Until EIP-712 metadata mismatch (D-4) and AR-13 (G-7 execution) are closed.

---

## Decision 7: G-2/G-3 — Implementation & Release Acceptance

**DECIDED: ✅ NO ACTION** — Until G-2 technical work finishes.

**Blocked on:**
- Invariant re-run (in progress)
- R10 mutation re-run (Gambit unavailable)
- R11 Halmos re-verification (Halmos unavailable)

---

## Outstanding Items Needing Elijah

| Item | What's needed |
|------|---------------|
| 2B | Designate 2 additional Safe owners |
| 2C | Designate pause guardian address |
| D-4 | EIP-712 metadata fix (MUSE can do — `deployment.json` version "1" → "2") |
| G-7 | Execute timelock + Safe deployment (after owners designated) |
