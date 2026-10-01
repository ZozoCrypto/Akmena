# G-7 Governance Decision Brief
**Date:** 2026-10-01
**Status:** DECISION REQUIRED — Elijah action
**Gate:** G-7 blocks mainnet deployment

## 1. Current Implementation (SOURCE-CONFIRMED)

### Allowlist Administration
**File:** `src/authorization/AkmenaPolicyBoundary.sol:141-144`
```solidity
// Interim: deployer holds both paths. G-7 migrates allowlistAdmin to
// the TimelockController and emergencyAdmin to the multisig.
allowlistAdmin = core.deployer();
emergencyAdmin = core.deployer();
```

| Role | Current holder | Powers |
|------|---------------|--------|
| `allowlistAdmin` | `core.deployer()` (interim) | Add/remove economic adapters (slow path); transfer role |
| `emergencyAdmin` | `core.deployer()` (interim) | Remove adapters ONLY (fast path); transfer role |

**Designated future holder (2026-09-29):** Elijah — `0x2D4888499D765d387f9CbC48061b28CDe6bC2601` (ENS: `cryptozozo.eth`, asserted by Elijah; on-chain ENS resolution unavailable at designation time).

### Pause Guardian
**File:** `src/core/AkmenaCore.sol:75-91`

| Action | Who | Notes |
|--------|-----|-------|
| Pause (`setPaused(true)`) | `pauseGuardian` OR `deployer` | Immediate, no delay. Fail-closed by design. |
| Unpause (`setPaused(false)`) | `deployer` ONLY | Guardian cannot unpause. Prevents compromised guardian from silently resuming. |
| Set guardian | `deployer` only | Set to `address(0)` to disable. |

**Status:** Pause guardian **NOT DESIGNATED**. The role exists in code but no address assigned.

### Dead Code (Verified)
`src/governance/AkmenaTimelock.sol` and `src/governance/AkmenaGovernor.sol` exist but are **unwired dead code**:
- Nothing references them
- No deploy script deploys them
- `AkmenaTimelock` has `governor`, `guardian`, `GRACE_PERIOD = 14 days`
- `AkmenaGovernor` has 3-day timelock delay, 1M token proposal threshold

## 2. Timelock Options

### Option A: OpenZeppelin TimelockController (RECOMMENDED)
- **What:** Battle-tested, audited, industry standard. Used by Compound, Uniswap, Aave.
- **Delay options:**
  - 24 hours: Minimum viable for emergency response. Allows overnight review.
  - 48 hours: Balanced. Allows weekend coverage.
  - 72 hours: Maximum caution. Slows emergency adapter replacement.
- **Pros:** Audited, standard interface, tooling support (Tenderly, Safe integration).
- **Cons:** Adds external dependency (though OZ is already used).

### Option B: Wire existing AkmenaTimelock
- **What:** Complete the `AkmenaTimelock` contract, write deploy script, audit.
- **Pros:** No new dependency, custom-fit to Akmena's governance model.
- **Cons:** Unaudited custom code for a critical security component. Requires full audit before mainnet. The `guardian` role and `guardianSunset` mechanism need review.

### Option C: No timelock (NOT RECOMMENDED)
- **What:** Multisig acts directly without delay.
- **Cons:** Violates spec §7.1. No cancellation window for malicious adapter adds. Single compromised multisig key-holder can immediately allowlist a drain adapter.

## 3. Multisig Options

### Recommended: Safe (formerly Gnosis Safe)
- **Threshold options:**
  - 2-of-3: Operational efficiency. Risk: 2 key compromises = full control.
  - 3-of-5: Balanced security. Recommended for mainnet.
  - 4-of-7: Maximum decentralization. Slower emergency response.
- **Key holder candidates:**
  - Elijah (designated): `0x2D4888499D765d387f9CbC48061b28CDe6bC2601`
  - Additional holders: **TO BE DESIGNATED BY ELIJAH**
- **Roles:**
  - `emergencyAdmin` (fast path): The multisig directly. Can remove adapters immediately.
  - `allowlistAdmin` (slow path): The timelock contract (which is controlled by the multisig via queued proposals).

### Alternative: Custom multisig
- **Not recommended.** Safe is the standard; custom multisig code is a needless risk.

## 4. Pause Guardian Options

### Option A: Elijah holds it (SIMPLEST)
- **What:** Elijah's operational key is the `pauseGuardian`.
- **Pros:** Single accountable party. Immediate response.
- **Cons:** Single point of failure. If Elijah is unavailable, no one can pause.

### Option B: Separate operational key (RECOMMENDED)
- **What:** A dedicated hot key (e.g., on a hardware wallet or secure enclave) held by Elijah or a trusted operator.
- **Pros:** Separation of concerns. Deployer key stays cold. Guardian key can be rotated without affecting deployment.
- **Cons:** Key management overhead.

### Option C: Multisig is the guardian
- **What:** The Safe multisig address is set as `pauseGuardian`.
- **Pros:** No single point of failure.
- **Cons:** Slower (requires threshold signatures). Defeats the purpose of "immediate" pause.

### Option D: No guardian (deployer only)
- **What:** Set `pauseGuardian = address(0)`. Only deployer can pause.
- **Pros:** Simplest. No additional key to manage.
- **Cons:** If deployer key is cold storage, pausing requires unsealing it (slow).

## 5. Verified Gaps

| Gap | Severity | Status |
|-----|----------|--------|
| Timelock not wired | **BLOCKING** | No timelock contract deployed or connected to `allowlistAdmin` |
| Multisig not deployed | **BLOCKING** | No Safe deployed; `emergencyAdmin` still = deployer |
| Pause guardian not designated | **HIGH** | Role exists but `pauseGuardian` = `address(0)` (disabled) |
| `AkmenaTimelock` dead code | MEDIUM | Either wire it (with audit) or delete it to avoid confusion |
| No incident-response runbook | MEDIUM | Spec §7.1 outlines the sequence but no operational runbook exists |
| No adapter-update monitoring | MEDIUM | `EconomicAdapterUpdated` event exists but no monitoring/alerting specified |

## 6. Consequences

### If G-7 is not completed before mainnet:
- **Deployer compromise = total loss.** The deployer holds both `allowlistAdmin` and `emergencyAdmin`. A compromised deployer key can immediately allowlist a malicious adapter and drain all operator allowances (AR-13).
- **No cancellation window.** Without a timelock, a malicious adapter add is immediately effective. Operators have no time to revoke allowances.
- **No emergency pause.** Without a designated guardian, pausing requires the deployer key (possibly in cold storage).

### If G-7 is completed:
- **Blast radius reduced.** Timelock delay gives operators time to revoke allowances if a malicious adapter is queued.
- **Fast containment.** Multisig can remove adapters immediately; guardian can pause immediately.
- **Slow recovery.** Adding a remediated adapter requires full timelock delay (deliberate, not rushed).

## 7. Recommendation

### Timelock: OpenZeppelin TimelockController, 48-hour delay
- **Rationale:** Battle-tested, standard, 48h balances security with operational needs. The existing `AkmenaTimelock` is unaudited custom code; wiring it would require a full audit anyway.

### Multisig: Safe, 3-of-5 threshold
- **Rationale:** Industry standard. 3-of-5 provides good security without excessive coordination overhead.
- **Key holders:** Elijah designates 5 holders (including himself). At least 2 should be non-Elijah for decentralization.

### Pause Guardian: Separate operational key (Option B)
- **Rationale:** Deployer key stays cold. Guardian key is hot but limited (can only pause, cannot unpause or modify allowlist). If compromised, deployer can rotate it via `setPauseGuardian`.

### Migration sequence:
1. Deploy Safe (3-of-5) with designated holders.
2. Deploy OZ TimelockController (48h delay) with Safe as proposer/executor.
3. Deployer calls `transferAllowlistAdmin(timelockAddress)`.
4. Deployer calls `transferEmergencyAdmin(safeAddress)`.
5. Deployer calls `setPauseGuardian(guardianKey)`.
6. Verify: deployer can no longer add/remove adapters or pause.
7. Document the incident-response runbook.

## 8. Assumptions

- **ASSUMPTION:** Elijah will designate the additional 4 multisig key holders. Their identities and key security practices are outside the scope of this brief.
- **ASSUMPTION:** The 48-hour timelock delay is acceptable for the protocol's operational needs. If faster adapter rotation is required, consider 24h.
- **ASSUMPTION:** The pause guardian key will be held securely (hardware wallet or equivalent). Compromise of the guardian key allows only pausing (denial of service), not fund theft.
- **ASSUMPTION:** Operators monitor the `EconomicAdapterUpdated` event and will revoke allowances if a malicious adapter is queued during the timelock delay. This is an off-chain social assumption, not enforced on-chain.
- **NOT-ASSESSED:** The specific Safe deployment parameters (nonce, version, network). These are operational details for the deployment ceremony.
- **NOT-ASSESSED:** Whether the existing `AkmenaTimelock`/`AkmenaGovernor` should be deleted or kept for future use. Recommendation: delete to avoid confusion, or clearly mark as deprecated.

## Decisions Required from Elijah

1. **Timelock:** Approve OZ TimelockController with 48h delay? (Or choose alternative)
2. **Multisig:** Approve Safe 3-of-5? Designate the 4 additional key holders.
3. **Pause guardian:** Approve separate operational key? Designate the holder.
4. **Timeline:** When should the migration ceremony occur? (Pre-mainnet, obviously, but specific date?)
