# Slither Triage Report
**Date:** 2026-10-01
**Tool:** Slither 0.11.6
**Scope:** `src/authorization/`, `src/core/`, `src/economics/` (Model D settlement layer)
**Excluded:** `lib/` (third-party), `src/privacy/` (deferred), `src/token/` (out of scope)
**Raw results:** 6 High, 17 Medium, 32 Low, 132 Informational (unfiltered)
**In-scope High/Medium:** 5 (2 High, 3 Medium)

---

## High Findings

### H-1: `arbitrary-send-erc20` in `AkmenaPolicyBoundary._settleERC20`
**Location:** `src/authorization/AkmenaPolicyBoundary.sol:519-587`
**Code:** `IERC20(intent.asset).safeTransferFrom(intent.operator, address(this), intent.amount)`
**Disposition:** SAFE-BY-DESIGN

**Rationale:**
The `intent.operator` is not arbitrary. It is constrained by:
1. EIP-712 signature verification — the intent must be signed by `intent.agent`
2. Boundary enforces `msg.sender == intent.agent` (caller gate)
3. Operator must have set an allowance for the boundary (or the transfer reverts)
4. Spending policy (`maxSpendPerTransaction`, `dailyLimit`) must allow the amount
5. Economic adapter must be allowlisted for the asset

This is the core Model D mechanism: pulling from the operator's wallet via their pre-approved allowance. Slither flags it because it cannot reason about the EIP-712 authorization context. The "arbitrary from" is the operator who authorized the pull by signing the intent and setting the allowance.

**Evidence:** R9 Medusa campaign (11,114 calls, 0 failures) exercises this path. `MedusaSettlementProof.t.sol` verifies exact pull amounts.

---

### H-2: `arbitrary-send-erc20` in `EscrowEngine._createEscrow`
**Location:** `src/economics/EscrowEngine.sol:89-151`
**Code:** `escrowAsset.safeTransferFrom(buyer, address(this), amount)` (line 118)
**Disposition:** SAFE-BY-DESIGN

**Rationale:**
The `buyer` is constrained to `msg.sender` (enforced at function entry). This is the escrow funding mechanism: the buyer funds their own escrow. The "arbitrary from" is the caller funding their own position. There is no scenario where an attacker can cause this to pull from a victim's wallet because `buyer == msg.sender` is enforced.

**Evidence:** Post-`8deead98` hardening (58→261 lines) with balance-delta funding check. R11 symbolic properties cover escrow caller gates.

---

## Medium Findings

### M-1: `unused-return` in `AkmenaPolicyBoundary._verifyActiveEscrow`
**Location:** `src/authorization/AkmenaPolicyBoundary.sol:310-329`
**Code:** `(moduleAddr, active, None) = core.getModule(intent.proofModuleKey)` — ignores `version` string
**Disposition:** FALSE POSITIVE

**Rationale:**
The function uses `moduleAddr` and `active`; the `version` string is intentionally ignored. This is not a bug — it's selective destructuring. The return value is not "unused" in a way that affects correctness.

---

### M-2: `unused-return` in `AkmenaPolicyBoundary.executeAuthorizedAgentCall`
**Location:** `src/authorization/AkmenaPolicyBoundary.sol:353-506`
**Code:** `executionAuthorization.verifyAndConsume(intent, payload, msg.value, signature)` — return value (signer address) ignored
**Disposition:** SAFE-BY-DESIGN

**Rationale:**
`verifyAndConsume` reverts on any validation failure (`InvalidSigner`, `InvalidAgent`, `NonceAlreadyUsed`, etc.). The return value is the signer address, which is already known: the boundary enforces `msg.sender == intent.agent` before calling, and `verifyAndConsume` verifies the signature recovers to `intent.agent`. Ignoring the redundant return value does not affect security — the revert-on-failure is the security property.

---

### M-3: `unused-return` in `DelegationEngine._validateIdentity`
**Location:** `src/authorization/DelegationEngine.sol:125-132`
**Code:** `IIdentity(identity).identityId()` — return value ignored
**Disposition:** FALSE POSITIVE

**Rationale:**
This is an existence check. Calling `identityId()` on an address with no code reverts; on a valid identity contract it succeeds. The return value itself is not needed — the call's success/failure is the signal. This is a common pattern.

---

## Summary

| ID | Severity | Check | Disposition |
|----|----------|-------|-------------|
| H-1 | High | arbitrary-send-erc20 (`_settleERC20`) | SAFE-BY-DESIGN |
| H-2 | High | arbitrary-send-erc20 (`_createEscrow`) | SAFE-BY-DESIGN |
| M-1 | Medium | unused-return (`_verifyActiveEscrow`) | FALSE POSITIVE |
| M-2 | Medium | unused-return (`executeAuthorizedAgentCall`) | SAFE-BY-DESIGN |
| M-3 | Medium | unused-return (`_validateIdentity`) | FALSE POSITIVE |

**Result:** Zero findings require code changes. All 5 in-scope High/Medium findings are dispositioned as safe-by-design or false positives with rationale.

**Note:** The 32 Low and 132 Informational findings were not individually triaged. They are predominantly style/lint issues (e.g., "too many digits" in OZ literals, naming conventions). If Elijah wants a full low/informational triage, that can be done as follow-up.
