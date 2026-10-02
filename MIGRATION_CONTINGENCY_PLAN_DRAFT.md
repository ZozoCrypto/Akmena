# Akmena Migration Contingency Plan (DRAFT)
**Status:** DRAFT — Not approved. Review required before mainnet.
**Date:** 2026-10-01
**Ref:** Spec §8 (M-1/M-2/M-3), V-9 inspection 2026-10-01

---

## 1. Context

Model D changes the custody model from pooled (Model C) to operator-retained. Any deployment running the pre-Model-D boundary holds funds under the old accounting. Migration moves from the old deployment to the new one.

**V-9 status (2026-10-01):** One legacy boundary on Base Sepolia (`0xdC3fC3e840b14Ce345638549D0d4617b75cD89b9`). Self-adapter grants NOT-ASSESSED (cannot enumerate without asset addresses). No mainnet deployments in repo records.

---

## 2. Migration Postures (M-1/M-2/M-3)

### M-1: Migration Plan Approval (Elijah Decision Required)

Before any migration, Elijah must approve:
- [ ] Which legacy deployment is being migrated (chain, addresses, block)
- [ ] V-9 inspection results for that deployment (self-adapter grants assessed or explicitly accepted as unknown)
- [ ] Target posture: M-2 (revoke-then-frozen) or M-3 (recovery adapter)

**Default posture: M-2 (revoke-then-frozen).** M-3 requires explicit justification (see §4).

### M-2: Revoke-Then-Frozen (Default)

**Steps:**
1. Pause the legacy boundary (if pause is available on that deployment)
2. Notify all operators to revoke allowances to the legacy boundary
3. Allow a revocation window (duration set by Elijah, suggested minimum 7 days)
4. After the window: declare the legacy deployment frozen
5. Deploy the new Model D boundary
6. Operators set fresh allowances and policies on the new deployment

**Rationale:** Clean break. No shared state. No recovery-adapter trap.

**Residual risk:** Funds in the legacy boundary that operators do not withdraw are stranded. This must be communicated before the migration.

### M-3: Recovery Adapter (Requires Explicit Approval)

**WARNING — Read F-8 first.**

The recovery adapter is a special economic adapter that pulls stranded funds from the legacy boundary to a Safe multisig for redistribution.

**Why this is dangerous:**
Adapter allowlisting is per (asset, adapter), not per operator. During the recovery window, ANY holder of a self-registered policy on the legacy boundary can drain through the recovery adapter — not just the intended recipients.

**Using the V-0 mechanism as a recovery tool reopens V-0 to all comers.**

**M-3 is approved ONLY if ALL of these hold:**
- [ ] The legacy boundary has zero self-adapter grants (confirmed, not assumed)
- [ ] All operators with policies on the legacy boundary are known and cooperative
- [ ] The recovery window is minimized (hours, not days)
- [ ] The recovery adapter is removed immediately after the window
- [ ] Elijah has explicitly approved M-3 over M-2 in writing

**If any condition fails: use M-2.**

---

## 3. Per-Deployment Checklist (M-1b)

For each legacy deployment being migrated:

- [ ] **Contract verification:** Confirm the deployed bytecode matches the expected source revision
- [ ] **Deployer key holder:** Identify who holds the deployer key (needed for pause/migration)
- [ ] **Pause capability:** Can the legacy boundary be paused? (Check `AkmenaCore.paused` and guardian)
- [ ] **Fund-movement paths:** Map all ways funds can leave the legacy boundary
- [ ] **Operator enumeration:** List all operators with allowances or policies (from events)
- [ ] **Balance snapshot:** Record all token balances held by the legacy boundary at migration block
- [ ] **Upgradeability:** Is the legacy boundary behind a proxy? (Affects migration options)

---

## 4. Stranded Funds Policy

**Definition:** Funds in the legacy boundary that are not withdrawn during the migration window.

**Policy (to be set by Elijah before migration):**
- Expiry: After ___ days (suggested: 180 days), unclaimed funds are declared expired
- Post-expiry destination: [ ] Treasury Safe / [ ] Burn / [ ] Other: ___
- This must be declared BEFORE the migration window opens, never after

**Trust assumptions for off-chain reconciliation:**
- (a) Trusts multisig operators + record completeness
- (b) Trusts the Merkle-root publisher (reproducible from public chain data)
- (c) No technical trust assumptions beyond the above

---

## 5. Rollback

If migration fails partway:
- **Before new deployment:** Abort. Legacy remains authoritative.
- **After new deployment but before freeze:** Both deployments exist. Communicate clearly which is authoritative. Complete the migration or roll back operator configurations.
- **After freeze:** No rollback. The legacy deployment is frozen. Fix-forward on the new deployment.

---

*End of plan. Requires Elijah's M-1 approval before any migration activity.*
