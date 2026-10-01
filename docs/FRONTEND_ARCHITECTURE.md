# Akmena Secure Frontend — Architecture Design

**Status:** DESIGN ONLY. No build. Blocked on deployment provenance (see §7).
**Date:** 2026-10-01
**Author:** Muse

## 1. Current State Assessment

### What exists
- Vite + React + TypeScript frontend in `frontend/`
- wagmi/viem for wallet connection and contract interaction
- EIP-712 signing flow in `src/features/execution/useExecutionIntent.ts`
- **Correct pattern:** reads EIP-712 domain live from chain via `readDomain()`, asserts chain ID and verifying contract before signing

### What's broken
1. **`src/config.ts` — stale addresses:**
   - `privacyEngine: '0x7e5095d10a4B71220938b816398918239981030a'` → **dead address** (0x code on Base Sepolia AND mainnet). Must be removed or replaced after redeploy.
   - `policyBoundary`, `akmenaCore`, `escrowEngine` — provenance unverified against `deployments/base-sepolia/deployment.json`
   - No PrivacyEngine entry in deployment.json at all

2. **`deployments/base-sepolia/deployment.json` — stale:**
   - Records only 4 contracts (~36 missing)
   - Says EIP-712 version `"1"`, code uses `"2"` → signatures built from this file would be rejected
   - No PrivacyEngine entry

3. **ABIs in `src/abi/`** — must be regenerated from current `src/` after any contract change

## 2. Signing Flow Architecture

### EIP-712 Domain (v2)
```
name: "AkmenaExecutionAuthorization"
version: "2"  ← CRITICAL: v1 signatures are invalid
chainId: 84532 (Base Sepolia) / 845 (Base mainnet)
verifyingContract: <executionAuthorization address>  ← read live from boundary
```

### Flow
```
1. User connects wallet (operator)
2. Frontend reads policyBoundary address from config
3. Frontend calls boundary.executionAuthorization() → auth address
4. Frontend reads EIP-712 domain from auth contract (live)
5. Frontend asserts: chainId matches, verifyingContract matches auth
6. User fills intent form (agent, target, asset, amount, etc.)
7. Frontend fetches next nonce for (agent) from auth.usedNonces
8. Frontend builds ExecutionIntent struct
9. Frontend computes digest via auth.hashIntent (or locally)
10. User signs via wallet (signTypedData)
11. Frontend verifies signature recovers to agent address (local check)
12. Agent (or relayer) submits to boundary.executeAuthorizedAgentCall
```

### Security invariants
- **Never trust config for domain:** always read live from chain
- **Always verify chain ID** before signing (prevent cross-chain replay)
- **Always verify verifyingContract** matches the auth contract being called
- **Nonce must be fetched live** — never cached across sessions
- **Signature verification** before submission (recover signer, compare to agent)

## 3. Component Architecture

```
src/
├── config.ts              ← ADDRESSES (must be generated from deployment.json)
├── features/
│   ├── execution/         ← Intent builder + signing (EXISTS, needs audit)
│   │   ├── useExecutionIntent.ts
│   │   ├── ExecutionScreen.tsx
│   │   └── executionChain.ts
│   ├── approvals/         ← Approval review flow (EXISTS)
│   ├── agents/            ← Agent management
│   ├── payments/          ← Payment flows
│   ├── security/          ← Security dashboard
│   └── overview/          ← Overview
├── components/
│   ├── ui/                ← Design system
│   ├── navigation/
│   └── status/
└── abi/                   ← GENERATED from src/, never hand-edited
```

### New components needed
- `DeploymentVerifier.tsx` — on startup, verify all config addresses have code on chain, domains match expected
- `PolicyViewer.tsx` — read and display agent policies from boundary
- `GovernancePanel.tsx` — for allowlistAdmin/emergencyAdmin (gated by connected wallet)

## 4. Address Management

### The problem
Hardcoded addresses in `config.ts` are a liability. They go stale, they can't be verified, and a wrong address means signing for the wrong contract.

### Solution: generated config
```typescript
// config.ts — GENERATED, do not hand-edit
// Generated from deployments/base-sepolia/deployment.json
// Deployment tx: <tx hash>
// Block: <block number>
// Generator: script/GenerateFrontendConfig.s.sol
```

A Foundry script reads `deployment.json`, verifies each address has code on the target chain, and writes `config.ts`. This runs as part of the deployment pipeline, not manually.

### Startup verification
On app load:
1. For each address in config, check `code.length > 0` on the connected chain
2. Read EIP-712 domain from auth, verify version = "2"
3. If any check fails, show blocking error — do NOT allow signing

## 5. Privacy UI — Parked

The PrivacyEngine UI must NOT be built until:
- Privacy v2 direction is decided (Akmena-operated vs defer)
- A real PrivacyEngine is deployed with verified address
- The dead address is removed from config

Building UI against `0x7e5095d10a4B71220938b816398918239981030a` would create a UI that appears functional but interacts with nothing.

## 6. Security Checklist (pre-build)

- [ ] `deployment.json` regenerated with all contracts, correct EIP-712 version
- [ ] `config.ts` generated from `deployment.json` via script
- [ ] All ABIs regenerated from current `src/`
- [ ] Dead privacyEngine address removed
- [ ] Startup deployment verifier implemented
- [ ] EIP-712 domain assertion covers version "2"
- [ ] Nonce fetched live, never cached
- [ ] Signature recovery check before submission
- [ ] Chain ID assertion on every signing flow
- [ ] No private keys in frontend code or env files
- [ ] CSP headers configured
- [ ] No `eval()` or dynamic code loading

## 7. Blockers (why this is design-only)

1. **Deployment provenance:** `deployment.json` is stale. Cannot generate trustworthy `config.ts` until it's fixed.
2. **G-7 governance:** Production timelock/multisig not finalized. Frontend governance UI can't be built against TBD addresses.
3. **Privacy direction:** Undecided. Privacy UI parked.
4. **Contract stability:** R9/R10/R11 still in flight. ABI regeneration must wait for contract freeze.

## 8. Next Steps (when unblocked)

1. Fix `deployment.json` (regenerate from actual deployment)
2. Run `script/GenerateFrontendConfig.s.sol` to generate `config.ts`
3. Regenerate ABIs: `forge build` + export
4. Implement `DeploymentVerifier.tsx`
5. Audit `useExecutionIntent.ts` against §2 invariants
6. Build missing components (§3)
7. Security review of full signing flow
8. Deploy to staging, test against Base Sepolia
