# Frontend Reconnaissance — Model D Scope

**Date:** 2026-10-03
**Status:** RECON ONLY — no production code implemented
**Invariant run:** Uninterrupted (4/17 at time of writing)

---

## 1. What the Frontend Must Expose for Model D

### Critical (Model D does not work without these)

| Feature | Contract Function | Status in Current Frontend |
|---------|-------------------|---------------------------|
| **Set agent spending policy** | `boundary.setAgentPolicy(agent, maxSpend, dailyLimit, requireEscrow)` | ❌ ABI has it, no UI |
| **Set per-asset policy** | `boundary.setAgentAssetPolicy(agent, asset, maxSpend, dailyLimit, requireEscrow)` | ❌ ABI has it, no UI |
| **Approve boundary allowance** | `token.approve(boundary, amount)` (ERC20) | ❌ **MISSING** — No allowance UI at all |
| **View allowance** | `token.allowance(operator, boundary)` (ERC20) | ❌ **MISSING** |
| **Revoke allowance** (kill-switch) | `token.approve(boundary, 0)` | ❌ **MISSING** |
| **View current policy** | `boundary.agentPolicies(agent, asset)` | ❌ No UI |
| **View daily spend** | `boundary.agentPolicies(agent, asset).totalSpentToday` | ❌ No UI |

**The allowance gap is critical:** In Model D, the boundary pulls tokens from the
operator via `transferFrom`. Without a UI to approve/revoke the allowance, the
operator cannot fund agent execution or exercise the kill-switch. This is the
#1 frontend blocker for Model D usability.

### Important (Needed for full workflow)

| Feature | Contract Function | Status |
|---------|-------------------|--------|
| **Sign execution intent** (EIP-712) | Off-chain signing, `executionAuthorization.eip712Domain()` | ⚠️ Partial — approval flow exists |
| **Execute authorized call** | `boundary.executeAuthorizedAgentCall(intent, payload, sig)` | ⚠️ Partial — via approvals screen |
| **View EIP-712 domain** | `executionAuthorization.eip712Domain()` | ✅ Read in `useAkmenaOnchainState` |
| **Pause status** | `core.isPaused()` / `core.paused()` | ✅ Read in `useAkmenaOnchainState` |
| **Create escrow** | `escrow.createEscrow(...)` | ⚠️ Escrow hooks exist, check coverage |
| **Release/refund escrow** | `escrow.releaseEscrow()` / `escrow.refundEscrow()` | ⚠️ Check coverage |

### Governance (G-7)

| Feature | Contract Function | Status |
|---------|-------------------|--------|
| **View pause guardian** | `core.pauseGuardian()` | ❌ No UI |
| **View pending deployer** | `core.pendingDeployer()` | ❌ No UI |
| **View allowlistAdmin** | `boundary.allowlistAdmin()` | ❌ No UI |
| **View emergencyAdmin** | `boundary.emergencyAdmin()` | ❌ No UI |
| **Propose deployer transfer** | `core.proposeDeployer(newDeployer)` | ❌ No UI |
| **Accept deployer transfer** | `core.acceptDeployer()` | ❌ No UI |

---

## 2. Contract/API Surface Dependencies

### Contracts the Frontend Depends On

| Contract | ABI Present | Address in Config | Status |
|----------|-------------|-------------------|--------|
| AkmenaCore | ✅ `AkmenaCore.json` | `0x0C4710331d6e234fE311C1c27252Ad63b7A6ac99` | ⚠️ Verify not deprecated |
| AkmenaPolicyBoundary | ✅ `AkmenaPolicyBoundary.json` | `0xdC3fC3e840b14Ce345638549D0d4617b75cD89b9` | ❌ **DEPRECATED** (G-5) |
| AkmenaExecutionAuthorization | ✅ `AkmenaExecutionAuthorization.json` | Derived at runtime | ✅ |
| EscrowEngine | ✅ `escrowAbi.ts` | `0x18FdA79e236E303d6de1Bf94a12E5137d45E3D84` | ⚠️ Verify not deprecated |
| PrivacyEngine | ✅ `PrivacyEngine.json` (staged) | `0x7e5095d10a4B71220938b816398918239981030a` | ❌ **DEAD** (returns 0x) |
| AkmenaToken (AKM) | ❌ No ABI | Not in config | ❌ **MISSING** — needed for approve/allowance |

### Key Finding: Config Points to Deprecated Addresses

`src/config.ts`:
- `policyBoundary`: `0xdC3fC3e840b14Ce345638549D0d4617b75cD89b9` — **DEPRECATED per G-5 decision**
- `privacyEngine`: `0x7e5095d10a4B71220938b816398918239981030a` — **DEAD** (no code)
- `defaultAiAgent`: `0xC72CBbeaf7F540522804BcbF592dc7a6b6906476` — matches temp Safe owner #3

The frontend cannot work against current contracts until the config is updated
with fresh deployment addresses (post G-7).

### ABIs Need Refresh

The staged ABIs (`src/abi/*.json`) predate recent changes:
- `setAgentAssetPolicy` — check if ABI matches current signature
- `proposeDeployer` / `acceptDeployer` / `cancelDeployerTransfer` — likely **missing** (added 2026-10-02)
- `UnauthorizedZeroAmountTarget` error — likely **missing** (added 2026-10-01)
- `setPauseGuardian` — check if present

**Recommendation:** Regenerate ABIs from current `src/` after the invariant run completes
and no more contract changes are pending.

---

## 3. Deferred Components — Accidental Inclusion Check

### PrivacyEngine

| Check | Result |
|-------|--------|
| ABI file exists (`src/abi/PrivacyEngine.json`) | ✅ Yes — **staged but unused** |
| Imported in any `.ts`/`.tsx` | ❌ No — not imported anywhere |
| Address in `config.ts` | ✅ Yes — `0x7e5095d10a4B71220938b816398918239981030a` (dead) |
| Called by any UI component | ❌ No |
| Referenced in routes | ❌ No |

**Verdict:** PrivacyEngine is **NOT accidentally included** in any user-facing flow.
The ABI is staged but dead code. The config address is dead.

**Recommendation:**
- Remove `privacyEngine` from `config.ts` OR mark as `// DEPRECATED — do not use`
- Delete `src/abi/PrivacyEngine.json` OR move to `src/abi/deprecated/`
- This prevents future developers from accidentally wiring it up

### Other Deferred Components

| Component | In Frontend | Status |
|-----------|-------------|--------|
| Model C (pooled custody) | ❌ No references | ✅ Correctly absent (G-6 FROZEN) |
| AkmenaGovernor / AkmenaTimelock | ❌ No references | ✅ Correctly absent (deleted 2026-10-01) |
| PrivacyEngine UI | ❌ No screens | ✅ Correctly absent |

---

## 4. Frontend Architecture Notes

**Stack:** React 19, Vite, wagmi v2, viem v2, OnchainKit, Tailwind CSS v4

**Structure:**
- `src/features/` — Screens by domain (agents, approvals, execution, payments, security, activity, overview)
- `src/data/onchain/` — Wagmi hooks for contract reads
- `src/data/escrow/` — Escrow-specific hooks
- `src/abi/` — Staged contract ABIs
- `src/config.ts` — Contract addresses and network config

**Current screens are largely mock/static:**
- `AgentsScreen.tsx` — hardcoded "Agent-007" with static values
- No live policy management
- No allowance management
- Approval flow exists but needs verification against current EIP-712 v2

---

## 5. Recommended Frontend Build Order (When Authorized)

### Phase 1: Fix Foundations
1. Update `config.ts` with fresh (non-deprecated) contract addresses
2. Regenerate ABIs from current `src/`
3. Remove or quarantine PrivacyEngine references
4. Add AkmenaToken ABI for approve/allowance

### Phase 2: Model D Core (Operator Workflow)
1. **Policy dashboard** — view/set `setAgentPolicy` and `setAgentAssetPolicy`
2. **Allowance manager** — approve/view/revoke ERC20 allowance to boundary
   - This is the kill-switch UI — must be prominent and easy to find
3. **Daily spend tracker** — show `totalSpentToday` vs `dailyLimit`

### Phase 3: Agent Execution Flow
1. **Intent builder** — construct EIP-712 intents
2. **Approval review** — review and sign intents (extend existing)
3. **Execution status** — track intent execution results

### Phase 4: Governance Visibility (Read-Only)
1. Show `pauseGuardian`, `allowlistAdmin`, `emergencyAdmin`
2. Show `pendingDeployer` if transfer in progress
3. Timelock status (if G-7 executed)

### Phase 5: Agent Commerce Playground (Grant Demo)
- Per `BASE_BUILDER_GRANT_DRAFT.md`: operator sets policy → agent executes commerce task → UI shows settlement → operator revokes to demonstrate fail-closed

---

## 6. Blockers Before Frontend Implementation

- [ ] Invariant re-run completes (contract code freeze)
- [ ] Fresh deployment addresses (post G-7 or fresh test deploy)
- [ ] ABIs regenerated from final `src/`
- [ ] Elijah approves frontend scope (per his "discuss before implementation" constraint)

---

**No contract code was altered in this reconnaissance.**
**No frontend production code was implemented.**
**Invariant run continues uninterrupted.**
