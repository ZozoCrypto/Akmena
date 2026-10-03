# G-7 Signer Rotation Procedure

**Status:** DRAFT — for review before any live transaction
**Temporary config date:** 2026-10-03
**Final production config:** PENDING

---

## Temporary Addresses (DO NOT USE FOR PRODUCTION)

| Role | Address | Status |
|------|---------|--------|
| Pause guardian (temp) | `0x2dd10bb5571f9086c789fd8c5e2b43545b74444f` | TEMPORARY |
| Safe owner #1 | `0x2D4888499D765d387f9CbC48061b28CDe6bC2601` (Elijah) | Permanent (Elijah) |
| Safe owner #2 (temp) | `0x002176469C1c635530c4AC30767dF1B9fbF529a3` | TEMPORARY |
| Safe owner #3 (temp) | `0xC72CBbeaf7F540522804BcbF592dc7a6b6906476` | TEMPORARY |
| Safe threshold | 2-of-3 | May change for production |

---

## Why Rotation Is Needed

The temporary addresses were provided for build/rehearsal/test. They must not become
the permanent production custody. Before mainnet (or before any production value
flows through the contracts), the temporary signers must be replaced with the
final production configuration via the procedure below.

**Critical:** Do not create a Safe with temporary owners and assume the Safe address
can be freely substituted later. The protocol's role assignments (`emergencyAdmin`,
timelock proposer/executor roles) point to a specific Safe address. Changing the
Safe means updating all role assignments through governance.

---

## Rotation Procedure

### Phase 1: Deploy Final Safe (Off-Chain)

1. Elijah designates the final 2-of-3 (or revised threshold) owner set.
2. Deploy the final Safe via the Safe UI or `safe-smart-account` contracts.
3. Record the final Safe address: `FINAL_SAFE = 0x...`
4. Verify owners and threshold on-chain via the Safe UI.

### Phase 2: Propose Rotation via Current Governance

The rotation must go through the **currently active** governance path:

**If G-7 is already executed (timelock + temp Safe active):**

1. The temporary Safe (2-of-3) proposes via the TimelockController:
   - Schedule `boundary.setEmergencyAdmin(FINAL_SAFE)` (24h delay)
   - Schedule `timelock.grantRole(PROPOSER_ROLE, FINAL_SAFE)` (24h delay)
   - Schedule `timelock.grantRole(EXECUTOR_ROLE, FINAL_SAFE)` (24h delay)
2. After 24h, the temporary Safe executes all three.
3. Verify:
   - `boundary.emergencyAdmin() == FINAL_SAFE`
   - `timelock.hasRole(PROPOSER_ROLE, FINAL_SAFE)`
   - `timelock.hasRole(EXECUTOR_ROLE, FINAL_SAFE)`
4. Optionally revoke the temporary Safe's roles:
   - `timelock.revokeRole(PROPOSER_ROLE, TEMP_SAFE)`
   - `timelock.revokeRole(EXECUTOR_ROLE, TEMP_SAFE)`

**If G-7 is NOT yet executed (deployer still in control):**

1. The deployer calls directly (no delay):
   - `boundary.setEmergencyAdmin(FINAL_SAFE)`
   - (Timelock not yet deployed — deploy with final Safe as proposer/executor)
2. This is simpler but means G-7 was never on temporary config.

### Phase 3: Rotate Pause Guardian

1. Via the active governance path (timelock or deployer):
   - `core.setPauseGuardian(FINAL_GUARDIAN)`
2. Verify: `core.pauseGuardian() == FINAL_GUARDIAN`
3. Confirm the temporary guardian address no longer has any role.

### Phase 4: Verification Checklist

- [ ] `boundary.emergencyAdmin()` == final Safe
- [ ] `boundary.allowlistAdmin()` == timelock (unchanged)
- [ ] `timelock.hasRole(PROPOSER_ROLE, FINAL_SAFE)` == true
- [ ] `timelock.hasRole(EXECUTOR_ROLE, FINAL_SAFE)` == true
- [ ] Temporary Safe has no roles (if revoked)
- [ ] `core.pauseGuardian()` == final guardian
- [ ] `core.deployer()` == timelock (unchanged)
- [ ] All temporary addresses documented as retired

### Phase 5: Documentation

1. Update this file: mark temporary addresses as RETIRED, record final addresses.
2. Update `DECISION_PACKET.md` with final configuration.
3. Update `deployment.json` with final Safe and guardian addresses.
4. Commit with message: `G-7: rotate from temporary to final signer configuration`

---

## Emergency: Temporary Signer Compromise

If a temporary signer is compromised **before** rotation:

1. **Pause guardian** (if compromised): The deployer (or timelock) can call
   `core.setPauseGuardian(NEW_GUARDIAN)` immediately. The compromised guardian
   can only pause (DoS), not steal funds.

2. **Safe owner** (if compromised): With 2-of-3 threshold, one compromised owner
   cannot act alone. Rotate immediately via Phase 2 above, prioritizing removal
   of the compromised owner.

3. **If 2 of 3 compromised:** This is a critical incident. Follow the
   `INCIDENT_RESPONSE_RUNBOOK_DRAFT.md`.

---

## Checklist Before Any Live Transaction

- [ ] Are we using temporary or final addresses?
- [ ] If temporary: is this a test/rehearsal (OK) or production (STOP)?
- [ ] Are owner/guardian parameters explicitly set (not hardcoded)?
- [ ] Has the role configuration been independently verified?
- [ ] Is the signer rotation procedure understood by all parties?

**Rule:** If any checkbox is unclear, STOP and confirm with Elijah before broadcasting.
