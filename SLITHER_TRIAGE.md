# Slither Triage Report
**Date:** 2026-10-01 (expanded per ChatGPT review)
**Tool:** Slither 0.11.6
**Raw results:** 6 High, 17 Medium, 32 Low, 132 Informational
**Scope note:** All 6 High findings triaged below. Medium/Low/Informational filtered to settlement layer.

---

## High Findings — Full Triage

### H-1: `arbitrary-send-erc20` in `AkmenaPolicyBoundary._settleERC20`
**Location:** `src/authorization/AkmenaPolicyBoundary.sol:564`
**Code:** `IERC20(intent.asset).safeTransferFrom(intent.operator, address(this), intent.amount)`
**Disposition:** SAFE-BY-DESIGN

#### Reachable Call Path
```
executeAuthorizedAgentCall(intent, payload, signature) [external]
  ├── msg.sender == intent.agent (else revert UnauthorizedAgent)
  ├── intent.target allowlisted: economicAdapters[asset][target] == true (else revert)
  ├── intent.target != intent.asset (else revert InvalidAdapter) [V-9 defense]
  ├── policy = _policy(intent.operator, msg.sender, intent.asset)
  ├── policy.maxSpendPerTransaction > 0 (else revert UnauthorizedAgent)
  ├── intent.amount <= policy.maxSpendPerTransaction (else revert PolicyExceeded)
  ├── auth.verifyAndConsume(intent, payload, msg.value, signature)
  │     ├── EIP-712 signature must recover to intent.agent (else revert InvalidSigner)
  │     ├── nonce must be unused (else revert NonceAlreadyUsed)
  │     └── deadline/validAfter checks
  └── _settleERC20(intent, payload, policy) [internal]
        ├── allowance(intent.operator, address(this)) >= intent.amount (else revert)
        ├── intent.amount <= dailyLimit headroom (else revert PolicyExceeded)
        ├── policy.totalSpentToday += intent.amount (charge-before-push)
        ├── safeTransferFrom(intent.operator, address(this), intent.amount) ← FLAGGED
        ├── safeTransfer(intent.target, intent.amount)
        └── intent.target.call(payload)
```

#### Exploit Analysis: Can an untrusted caller control recipient and amount?

**Attacker model:** Attacker is the agent (`msg.sender == intent.agent`). They craft a malicious intent.

**Q1: Can the attacker set `intent.operator` to a victim and drain them?**
No. Three independent gates block this:
1. **Allowance gate:** `safeTransferFrom(victim, ...)` reverts unless the victim previously approved the boundary. The attacker cannot forge an approval.
2. **Policy gate:** `_policy(victim, attacker, asset)` must exist with `maxSpendPerTransaction > 0`. Policies are created by the operator via `setAgentAssetPolicy` — only the victim can authorize the (victim, attacker) pair. The attacker cannot self-authorize.
3. **Signature gate:** The intent must be signed by `intent.agent` (the attacker). This is satisfied, but gates 1-2 still block.

**Q2: Can the attacker set `intent.target` to their own address?**
No. Two gates block this:
1. **Allowlist gate:** `economicAdapters[asset][target]` must be true for `amount > 0`. Only `allowlistAdmin` (deployer → future timelock) can set this. The attacker cannot self-allowlist.
2. **Self-adapter gate:** `intent.target == intent.asset` → revert `InvalidAdapter()`. This closes the V-9 legacy path.

**Q3: Can the attacker set `intent.amount` arbitrarily high?**
No. Three bounds apply:
1. `intent.amount <= policy.maxSpendPerTransaction` (operator-set)
2. `intent.amount <= dailyLimit - totalSpentToday` (operator-set headroom)
3. `intent.amount <= allowance(operator, boundary)` (operator's approval)

**Conclusion:** The "arbitrary" parameters are calldata-controlled but constrained by five independent authorization domains (EIP-712 signature, caller gate, allowlist, operator policy, operator allowance), each controlled by a different party. An untrusted caller cannot redirect funds or exceed operator-set bounds. This is defense-in-depth working as designed.

**Evidence:** R9 Medusa (11,114 calls, 0 failures) fuzzes this path. `MedusaSettlementProof.t.sol` verifies exact amounts. AR-3/AR-4 adversarial tests verify revocation and racing.

---

### H-2: `arbitrary-send-erc20` in `EscrowEngine._createEscrow`
**Location:** `src/economics/EscrowEngine.sol:118`
**Code:** `escrowAsset.safeTransferFrom(buyer, address(this), amount)`
**Disposition:** SAFE-BY-DESIGN

**Rationale:** `buyer == msg.sender` is enforced at function entry. The caller funds their own escrow. There is no path where an attacker causes this to pull from a victim's wallet.

**Evidence:** Post-`8deead98` hardening with balance-delta funding check. R11 symbolic properties cover escrow caller gates.

---

### H-3: `arbitrary-send-eth` in `PrivacyEngine.executePrivateSettlement`
**Location:** `src/privacy/PrivacyEngine.sol:56`
**Code:** `(success,None) = stealthRecipient.call{value: amount}()`
**Disposition:** OUT-OF-SCOPE (DEFERRED)

**Rationale:** PrivacyEngine is DEFERRED by Elijah's decision 2026-10-01. The contract is dead on both Base chains (address returns 0x). It will not be deployed. The finding is noted but not applicable to the settlement layer security posture.

---

### H-4: `arbitrary-send-eth` in `AkmenaPrivatePool.withdraw`
**Location:** `src/privacy/v2/AkmenaPrivatePool.sol:223,227`
**Code:** `(okR,None) = _recipient.call{value: recipientAmount}()`
**Disposition:** OUT-OF-SCOPE (DEFERRED)

**Rationale:** Privacy v2 is DEFERRED. This code is not part of the Model D settlement layer and will not be deployed to mainnet in its current form.

---

### H-5: `incorrect-exp` in OZ `Math.mulDiv`
**Location:** `lib/openzeppelin-contracts/contracts/utils/math/Math.sol:259`
**Code:** `inverse = (3 * denominator) ^ 2`
**Disposition:** FALSE POSITIVE (third-party, known)

**Rationale:** This is a well-documented Slither false positive on audited OpenZeppelin code. The `^` operator is bitwise XOR, used intentionally as part of Newton's method for computing modular inverses. It is not an exponentiation bug. OpenZeppelin's Math library is extensively audited and battle-tested.

---

### H-6: `incorrect-return` in `AkmenaPrivatePool.deposit`
**Location:** `src/privacy/v2/AkmenaPrivatePool.sol:132-140`
**Code:** Calls `_insert` which "halts the execution"
**Disposition:** OUT-OF-SCOPE (DEFERRED)

**Rationale:** Privacy v2 is DEFERRED. Not part of the settlement layer.

---

## Summary

| ID | Severity | Check | Location | Disposition |
|----|----------|-------|----------|-------------|
| H-1 | High | arbitrary-send-erc20 | `AkmenaPolicyBoundary._settleERC20` | SAFE-BY-DESIGN |
| H-2 | High | arbitrary-send-erc20 | `EscrowEngine._createEscrow` | SAFE-BY-DESIGN |
| H-3 | High | arbitrary-send-eth | `PrivacyEngine` | OUT-OF-SCOPE (deferred) |
| H-4 | High | arbitrary-send-eth | `AkmenaPrivatePool` | OUT-OF-SCOPE (deferred) |
| H-5 | High | incorrect-exp | OZ `Math.mulDiv` | FALSE POSITIVE (known) |
| H-6 | High | incorrect-return | `AkmenaPrivatePool` | OUT-OF-SCOPE (deferred) |

**Result:** Zero findings require code changes to the settlement layer. H-1 (the primary concern) is safe-by-design with five independent authorization gates documented above. H-3/H-4/H-6 are out-of-scope (privacy deferred). H-5 is a known third-party false positive.

## Medium Findings (Settlement Layer Only)

| ID | Check | Location | Disposition |
|----|-------|----------|-------------|
| M-1 | unused-return | `AkmenaPolicyBoundary._verifyActiveEscrow` | FALSE POSITIVE (selective destructuring) |
| M-2 | unused-return | `AkmenaPolicyBoundary.executeAuthorizedAgentCall` | SAFE-BY-DESIGN (revert-on-failure) |
| M-3 | unused-return | `DelegationEngine._validateIdentity` | FALSE POSITIVE (existence check) |

**Note:** 32 Low and 132 Informational findings not individually triaged (predominantly style/lint).
