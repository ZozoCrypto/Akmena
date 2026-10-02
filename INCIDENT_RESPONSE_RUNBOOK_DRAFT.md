# Akmena Incident Response Runbook (DRAFT)
**Status:** DRAFT — Not approved. Review required before mainnet.
**Date:** 2026-10-01

---

## 1. Severity Levels

| Level | Definition | Response Time |
|-------|------------|---------------|
| **P0 Critical** | Active fund loss, or imminent threat of fund loss | Immediate (minutes) |
| **P1 High** | Governance compromise, malicious adapter queued, guardian compromise | < 1 hour |
| **P2 Medium** | Suspicious activity, failed attack attempts, monitoring alerts | < 4 hours |
| **P3 Low** | Informational, post-mortem follow-ups | < 24 hours |

---

## 2. P0: Active Fund Loss

### 2.1 Containment (First 15 Minutes)

**Goal:** Stop the bleeding. Do not investigate yet — contain first.

1. **Pause the protocol** (any of these):
   - Guardian calls `core.setPaused(true)` — fastest if guardian key is hot
   - Deployer calls `core.setPaused(true)` — if guardian unavailable
   - Safe multisig calls `core.setPaused(true)` — if both above unavailable (slower)

2. **Verify pause took effect:**
   ```bash
   cast call <core_address> "paused()" --rpc-url <RPC>
   # Must return: true
   ```

3. **Alert all key holders** via the pre-established emergency channel.

### 2.2 Assessment (15-60 Minutes)

1. **Identify the attack vector:**
   - Check `EconomicAdapterUpdated` events for recent adapter changes
   - Check `ERC20Settled` events for unusual settlement patterns
   - Review pending timelock proposals

2. **Determine scope:**
   - Which assets are affected?
   - Which operators have allowances to the malicious adapter?
   - Is the attacker still active?

3. **Do NOT unpause** until the root cause is identified and remediated.

### 2.3 Remediation

1. **Remove the malicious adapter:**
   - Safe calls `boundary.emergencyRemoveAdapter(asset, adapter)` — immediate, no timelock

2. **Notify operators:**
   - Broadcast: revoke allowances to the malicious adapter
   - Provide the adapter address and the revocation call data

3. **Post-mortem:**
   - Document the attack vector, timeline, and fund impact
   - Identify how the adapter was allowlisted (governance failure?)
   - Update the Standard-Debit admission criteria if needed

4. **Recovery:**
   - Deploy remediated adapter (if applicable)
   - Queue via timelock (24h delay) — do not rush this
   - Unpause only after the malicious adapter is removed AND operators have had time to revoke

---

## 3. P1: Governance Compromise

### 3.1 Malicious Adapter Queued in Timelock

**Detection:** Monitoring alerts on `ProposalQueued` event in TimelockController.

1. **Verify the proposal:**
   - What adapter is being added? For which asset?
   - Who proposed it? (Should be the Safe)

2. **If unauthorized:**
   - Safe calls `timelock.cancel(proposalId)` — must be done within the 24h delay
   - Investigate how the proposal was created (Safe compromise?)

3. **If authorized but suspicious:**
   - Safe can still cancel during the delay — when in doubt, cancel
   - Re-propose after investigation if legitimate

### 3.2 Guardian Key Compromise

**Impact:** Attacker can pause the protocol (DoS only). Cannot unpause, cannot steal funds, cannot modify allowlist.

1. Deployer calls `core.setPauseGuardian(new_guardian_address)`
2. Verify `core.pauseGuardian()` returns the new address
3. If protocol was maliciously paused: deployer calls `core.setPaused(false)` to resume

### 3.3 Deployer Key Compromise (Pre-Migration)

**Impact:** CRITICAL. Deployer holds `allowlistAdmin` + `emergencyAdmin` + unpause.

1. **Immediately execute G-7 migration** from a secure backup key (if available)
2. If no backup key: the contracts are ungovernable — prepare for redeployment
3. Alert all operators to revoke allowances as a precaution

### 3.4 Multisig Owner Compromise

**Impact:** Depends on threshold. With 3-of-5, a single compromised owner cannot act alone.

1. Remaining owners vote to replace the compromised owner
2. If threshold is at risk (2 of 5 compromised): emergency pause via guardian, then reconstitute the Safe

---

## 4. P2: Suspicious Activity

### 4.1 Unusual Settlement Patterns

**Detection:** Monitoring alerts on `ERC20Settled` events.

1. Review the settlements: amounts, frequency, operators, adapters
2. Check if amounts exceed normal operational patterns
3. If malicious: escalate to P0

### 4.2 Failed Attack Attempts

1. Document the attempt (transaction hash, attacker address, method)
2. Verify the defense worked as expected
3. If a new attack vector: update the threat model and consider a fix

---

## 5. Communication

### 5.1 Internal
- Emergency channel: [TO BE ESTABLISHED]
- Key holders: [TO BE LISTED]
- Escalation: Guardian → Deployer → Safe → Elijah

### 5.2 External (Operators)
- Broadcast channel: [TO BE ESTABLISHED]
- Message template for allowance revocation:
  ```
  URGENT: Revoke allowance to adapter <address> for asset <address>.
  Reason: [brief description]
  Call: IERC20(<asset>).approve(<boundary>, 0)
  ```

### 5.3 Public
- Do not disclose vulnerabilities before they are remediated
- Post-mortems published after remediation (timeline at Elijah's discretion)

---

## 6. Key Contacts

| Role | Name | Contact | Backup |
|------|------|---------|--------|
| Deployer | Elijah | [TO BE FILLED] | [TO BE FILLED] |
| Guardian | [TO BE DESIGNATED] | [TO BE FILLED] | [TO BE FILLED] |
| Safe Owner 1 | Elijah | [TO BE FILLED] | — |
| Safe Owner 2 | [TO BE DESIGNATED] | [TO BE FILLED] | — |
| Safe Owner 3 | [TO BE DESIGNATED] | [TO BE FILLED] | — |
| Safe Owner 4 | [TO BE DESIGNATED] | [TO BE FILLED] | — |
| Safe Owner 5 | [TO BE DESIGNATED] | [TO BE FILLED] | — |

---

## 7. Recovery Adapter Trap (F-8)

**WARNING:** The only in-protocol recovery path is allowlisting a recovery adapter that pulls funds to a Safe. But adapter allowlisting is per (asset, adapter), not per operator — so during the recovery window, ANY holder of a self-registered policy can drain through the recovery adapter.

**Using the V-0 mechanism as a recovery tool reopens V-0 to all comers.**

**Safe recovery options:**
1. Pause + off-chain reconciliation + multisig return (requires a funding path)
2. Timelocked adapter addition with explicit operator opt-in (slow, deliberate)
3. If no safe recovery path exists for a deployment: acknowledge it, do not improvise

---

*End of runbook. Review and rehearse before mainnet.*
