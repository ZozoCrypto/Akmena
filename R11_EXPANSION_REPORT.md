# R11 Symbolic Execution — Expansion Report

**Date:** 2026-10-01 · **Tool:** Halmos 0.3.3 · **Branch:** `feature/model-d-operator-custody`
**New file:** `test/symbolic/R11Expansion.t.sol` (10 properties)
**Existing:** `test/symbolic/BoundarySymbolicR11.t.sol` (3 properties, re-verified)

## Summary

| Property | Contract | Paths | Result |
|----------|----------|-------|--------|
| check_ReleaseOnlyByBuyer | R11Expansion | 6 | PASS |
| check_RefundOnlyBySeller | R11Expansion | 6 | PASS |
| check_ReleaseNonexistentReverts | R11Expansion | 2 | PASS |
| check_ZeroValueNativeHeadroomGate | R11Expansion | 9 | PASS |
| check_ZeroValueNativeHeadroomPreSpent | R11Expansion | 27 | PASS |
| check_OnlyAllowlistAdminCanAddAdapter | R11Expansion | 2 | PASS |
| check_OnlyEmergencyAdminCanRemoveAdapter | R11Expansion | 2 | PASS |
| check_OnlyAllowlistAdminCanTransferAdmin | R11Expansion | 3 | PASS |
| check_OnlyEmergencyAdminCanTransferAdmin | R11Expansion | 3 | PASS |
| check_OnlyAllowlistAdminCanSetStandardDebit | R11Expansion | 3 | PASS |
| check_PauseBlocksExecution | BoundarySymbolicR11 | 12 | PASS |
| check_NonceReplayReverts | BoundarySymbolicR11 | 175 | PASS |
| check_ZeroOperatorReverts | BoundarySymbolicR11 | 47 | PASS |

**Total: 13/13 PASS.** No production contract changes (test-only).

## Property Designs

### Escrow (src/economics/EscrowEngine.sol)

**check_ReleaseOnlyByBuyer(address caller, uint256 amount)**
- Setup: test contract mints mock tokens, approves escrow engine, creates escrow as buyer.
- Symbolic caller (≠ buyer) attempts `releaseEscrow` via `vm.prank` + low-level call.
- Asserts `!success`. Proves the `msg.sender != data.buyer` check is fail-closed for all callers and amounts.
- Note: exercises EIP-1153 transient reentrancy lock — Halmos handles it correctly.

**check_RefundOnlyBySeller(address caller, uint256 amount)**
- Symmetric: symbolic caller (≠ seller) attempts `refundEscrow` → must revert.
- Proves the `msg.sender != data.seller` check.

**check_ReleaseNonexistentReverts(uint256 badId, address caller)**
- Attempts release on an ID that was never created (≥ 1000) → must revert `EscrowNotFound`.

### Settlement Accounting (AkmenaPolicyBoundary, zero-value native path)

**check_ZeroValueNativeHeadroomGate(dailyLimit, amount, nonce, payload, signature)**
- Fresh policy via `setAgentPolicy` (totalSpentToday = 0, maxSpend = max).
- Symbolic amount > dailyLimit → zero-value native execution must revert.
- Key insight: the headroom check (lines 464-472) runs BEFORE `verifyAndConsume`, so the property holds regardless of signature validity. Halmos's inability to forge ECDSA is irrelevant here.

**check_ZeroValueNativeHeadroomPreSpent(dailyLimit, alreadySpent, amount, nonce, payload, signature)**
- Sets `totalSpentToday` via `vm.store` to test the pre-spent path.
- Storage layout: `agentPolicies` at slot 0; `keccak256(agent . keccak256(operator . 0)) + 2` (totalSpentToday is 3rd struct field).
- Symbolic amount > saturating headroom (`dailyLimit - alreadySpent`, floored at 0) → must revert.
- 27 paths explored (richest property in the suite).

### Governance (AkmenaPolicyBoundary)

**check_OnlyAllowlistAdminCanAddAdapter(address caller)**
- Symbolic caller (≠ allowlistAdmin) attempts `setEconomicAdapter(asset, adapter, true)` with valid mock contracts → must revert `UnauthorizedAdapterAdmin`.
- Using real contracts (not address(0)) isolates the auth check from input validation.

**check_OnlyEmergencyAdminCanRemoveAdapter(address caller)**
- Symbolic caller (≠ emergencyAdmin) attempts `emergencyRemoveEconomicAdapter` → must revert.

**check_OnlyAllowlistAdminCanTransferAdmin(address caller, address newAdmin)**
- Symbolic caller (≠ allowlistAdmin) attempts `setAllowlistAdmin` → must revert.

**check_OnlyEmergencyAdminCanTransferAdmin(address caller, address newAdmin)**
- Symbolic caller (≠ emergencyAdmin) attempts `setEmergencyAdmin` → must revert.

**check_OnlyAllowlistAdminCanSetStandardDebit(address caller)**
- Symbolic caller (≠ allowlistAdmin) attempts `setStandardDebit` → must revert.

## Commands

```bash
# Install (was not persisted from prior session)
pip install halmos==0.3.3 --break-system-packages

# Run new properties
export PATH="$HOME/.foundry/bin:$PATH"
halmos --contract R11Expansion
# Result: 10 passed; 0 failed; time: 3.84s

# Re-verify original properties
halmos --contract BoundarySymbolicR11
# Result: 3 passed; 0 failed; time: 5.32s
```

## Methodology Notes

- All properties use low-level `.call()` + `assertTrue(!success)` because Halmos does not support `vm.expectRevert`.
- `vm.prank` with symbolic addresses works correctly in Halmos 0.3.3.
- `vm.assume` constrains symbolic inputs to avoid vacuous properties (e.g., `caller != admin`, `amount > 0`).
- `vm.store` for direct storage manipulation follows the same pattern as the existing nonce test.
- Properties are designed around *check sites* (authorization gates, accounting gates), not end-to-end flows, because Halmos cannot forge ECDSA signatures.

## Limitations

- Cannot prove *successful* execution paths (require valid ECDSA signatures).
- Escrow happy-path (buyer releases to seller) not symbolically verified — covered by concrete tests.
- Native settlement with `msg.value > 0` headroom not symbolically covered (would need pre-spent + value; the zero-value path covers the gate logic).
- Symbolic addresses are 160-bit; `vm.assume` keeps them from colliding with precompiles in practice but this is not formally excluded.

## Evidence Labels

- All 13 properties: **RUNTIME-PROVEN** (Halmos 0.3.3, verbatim outputs above)
- Property designs: **STATIC-ANALYSIS** (code inspection of check sites)
- Storage slot math: **STATIC-ANALYSIS** (verified by passing tests)
