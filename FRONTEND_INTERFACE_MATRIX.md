# Model D Frontend Contract/Interface Matrix

**Date:** 2026-10-03
**Status:** SPEC ONLY — no UI implementation
**Source revision:** TBD (pending contract freeze)
**Author:** Muse, per Aegis review

> This matrix maps every planned UI feature to its contract dependencies.
> Review against actual Solidity interfaces before any UI code is written.

---

## 1. Allowance Manager (CRITICAL)

| UI Feature | Contract | Function | Read/Write | Required Role | Security-Sensitive |
|------------|----------|----------|------------|---------------|-------------------|
| View current allowance | ERC20 (e.g., AKM) | `allowance(operator, boundary)` | Read | Operator (own allowance) | Yes — shows exposure |
| Approve allowance | ERC20 | `approve(boundary, amount)` | Write | Operator (token owner) | **Yes — grants pull permission** |
| Revoke allowance (set to 0) | ERC20 | `approve(boundary, 0)` | Write | Operator (token owner) | **Yes — kill-switch** |
| View token metadata | ERC20 | `symbol()`, `decimals()`, `name()` | Read | Anyone | No |
| Show allowance vs policy | Boundary | `agentPolicies(agent, asset)` | Read | Operator | Yes — exposure analysis |
| Show daily spend | Boundary | `agentPolicies(agent, asset).totalSpentToday` | Read | Operator | Yes |

**Key distinction the UI must make obvious:**
- **ERC-20 allowance** = how much the boundary *can pull* from the operator's wallet
- **Policy limit** = how much the agent *is authorized to spend* per the boundary's rules
- Disabling a policy does **NOT** revoke the allowance — tokens remain exposed until allowance is set to zero
- The UI must show both side-by-side with a clear warning when allowance > 0 but policy is disabled/zero

**Solidity interfaces to verify:**
```solidity
// ERC20 (OpenZeppelin)
function allowance(address owner, address spender) external view returns (uint256);
function approve(address spender, uint256 amount) external returns (bool);

// AkmenaPolicyBoundary
struct SpendingPolicy {
    uint256 maxSpendPerTransaction;
    uint256 dailyLimit;
    uint256 totalSpentToday;
    uint256 lastResetTimestamp;
    bool requireActiveEscrow;
}
function agentPolicies(address agent, address asset) external view returns (SpendingPolicy memory);
```

---

## 2. Policy Dashboard

| UI Feature | Contract | Function | Read/Write | Required Role | Security-Sensitive |
|------------|----------|----------|------------|---------------|-------------------|
| View agent policy (native) | Boundary | `agentPolicies(agent, address(0))` | Read | Operator | Yes |
| View agent policy (per asset) | Boundary | `agentPolicies(agent, asset)` | Read | Operator | Yes |
| Set native policy | Boundary | `setAgentPolicy(agent, maxSpend, dailyLimit, requireEscrow)` | Write | Operator (own agent) or admin | **Yes — sets spending authority** |
| Set asset policy | Boundary | `setAgentAssetPolicy(agent, asset, maxSpend, dailyLimit, requireEscrow)` | Write | Operator (own agent) or admin | **Yes** |
| View registered agents | Boundary | *(no registry — agents are addresses)* | N/A | N/A | N/A |

**Note:** There is no on-chain agent registry. The UI must let the operator input
agent addresses manually or maintain a local list.

**Solidity interfaces to verify:**
```solidity
function setAgentPolicy(address agent, uint256 maxSpendPerTx, uint256 dailyLimit, bool requireEscrow) external;
function setAgentAssetPolicy(address agent, address asset, uint256 maxSpendPerTx, uint256 dailyLimit, bool requireEscrow) external;
```

---

## 3. Daily Spend Tracker

| UI Feature | Contract | Function | Read/Write | Required Role | Security-Sensitive |
|------------|----------|----------|------------|---------------|-------------------|
| Current daily spend | Boundary | `agentPolicies(agent, asset).totalSpentToday` | Read | Operator | Yes |
| Daily limit | Boundary | `agentPolicies(agent, asset).dailyLimit` | Read | Operator | Yes |
| Last reset timestamp | Boundary | `agentPolicies(agent, asset).lastResetTimestamp` | Read | Operator | No |
| Remaining budget | *(computed: dailyLimit - totalSpentToday)* | — | Read | Operator | Yes |

---

## 4. Agent Intents (Execution Flow)

| UI Feature | Contract | Function | Read/Write | Required Role | Security-Sensitive |
|------------|----------|----------|------------|---------------|-------------------|
| Get EIP-712 domain | ExecAuth | `eip712Domain()` | Read | Anyone | No |
| Get current nonce | ExecAuth | `nonces(agent)` | Read | Anyone | No |
| Sign intent (off-chain) | — | EIP-712 signing via wallet | Off-chain | Operator | **Yes — authorizes spend** |
| Execute authorized call | Boundary | `executeAuthorizedAgentCall(intent, payload, signature)` | Write | Anyone (with valid sig) | **Yes — moves funds** |
| Execute presigned (native) | Boundary | `executePresigned(intent, payload, signature)` | Write | Anyone (with valid sig + ETH) | **Yes** |

**Intent struct (verify against current source):**
```solidity
struct ExecutionIntent {
    address operator;
    address agent;
    address target;
    bytes4 selector;
    bytes32 proofModuleKey;
    address asset;
    uint256 amount;
    uint256 value;
    bytes32 nonce;
    uint256 deadline;
    uint256 chainId;
    // ... verify exact fields against AkmenaExecutionAuthorization.sol
}
```

**EIP-712 domain (verify):**
- Name: `AkmenaExecutionAuthorization`
- Version: `2` (v1 deprecated)
- Chain ID: varies by network
- Verifying contract: ExecAuth address

---

## 5. Escrow

| UI Feature | Contract | Function | Read/Write | Required Role | Security-Sensitive |
|------------|----------|----------|------------|---------------|-------------------|
| View escrow details | EscrowEngine | `escrows(escrowId)` | Read | Participant | Yes |
| Create escrow | EscrowEngine | `createEscrow(...)` | Write | Buyer | **Yes — locks funds** |
| Release escrow | EscrowEngine | `releaseEscrow(escrowId)` | Write | Buyer or arbiter | **Yes — releases funds** |
| Refund escrow | EscrowEngine | `refundEscrow(escrowId)` | Write | Per escrow terms | **Yes** |
| Total locked | EscrowEngine | `totalLocked(asset)` | Read | Anyone | No |

**Verify exact function signatures against `src/economics/EscrowEngine.sol`.**

---

## 6. Governance Visibility (Read-Only)

| UI Feature | Contract | Function | Read/Write | Required Role | Security-Sensitive |
|------------|----------|----------|------------|---------------|-------------------|
| Pause status | Core | `isPaused()` | Read | Anyone | Yes |
| Pause guardian | Core | `pauseGuardian()` | Read | Anyone | Yes |
| Current deployer | Core | `deployer()` | Read | Anyone | Yes |
| Pending deployer | Core | `pendingDeployer()` | Read | Anyone | Yes |
| Allowlist admin | Boundary | `allowlistAdmin()` | Read | Anyone | Yes |
| Emergency admin | Boundary | `emergencyAdmin()` | Read | Anyone | Yes |
| Check if adapter allowlisted | Boundary | `economicAdapters(asset, adapter)` | Read | Anyone | Yes |
| Check if standard debit | Boundary | `standardDebitAssets(asset)` | Read | Anyone | Yes |

**Note:** These are read-only in the frontend. Actual governance actions
(deployer transfer, role changes) go through the G-7 scripts, not the UI.

---

## 7. Security-Sensitive Operations Summary

Operations that move funds or grant permissions, requiring extra UI care:

| Operation | Risk | UI Requirement |
|-----------|------|----------------|
| `approve(boundary, amount)` | Grants pull permission | Show exact amount, asset, spender; warn if > policy limit |
| `approve(boundary, 0)` | Revokes permission | Confirm dialog; show what was revoked |
| `setAgentPolicy` / `setAgentAssetPolicy` | Sets spending authority | Show old vs new values; require confirmation |
| `executeAuthorizedAgentCall` | Moves funds | Show intent details; verify signature before broadcast |
| EIP-712 signing | Authorizes spend | Show human-readable intent; warn on unusual amounts |
| `createEscrow` | Locks funds | Show escrow terms; confirm buyer/seller/amount |

---

## 8. ABI Generation Checklist (Post-Freeze)

When the contract candidate is frozen:

- [ ] Record exact git revision (commit hash)
- [ ] Run `forge build` at that revision
- [ ] Extract ABIs from `out/` build artifacts
- [ ] Verify ABIs include:
  - [ ] `proposeDeployer`, `acceptDeployer`, `cancelDeployerTransfer`
  - [ ] `UnauthorizedZeroAmountTarget` error
  - [ ] `setAgentPolicy`, `setAgentAssetPolicy` (current signatures)
  - [ ] `agentPolicies` (current struct layout)
  - [ ] EIP-712 domain v2
- [ ] Record ABI generation command and timestamp
- [ ] Commit ABIs with message referencing source revision

**Traceability:** `contract revision → forge build → ABI → frontend`

---

## 9. Open Questions — Answered (2026-10-03)

### Q1: Multiple assets or AKM only?
**Recommendation: AKM only for MVP.**

Rationale: `setAgentAssetPolicy` supports per-asset policies, but multi-asset UI
adds significant complexity (per-asset allowance tracking, per-asset spend views).
AKM is the canonical asset with a 9/9 admission battery. Get the single-asset
flow right, then generalize. The interface matrix already structures policies
per-asset, so the extension point is clean.

### Q2: Admin view or own agents only?
**Recommendation: Connected wallet's agents only for MVP.**

Rationale: In Model D, the operator sets policy for their own agents. The
`setAgentPolicy` function technically allows setting policy for any agent address,
but the UI should scope to the connected wallet to avoid confusion about authority.
An admin view (for allowlistAdmin/emergencyAdmin roles) is a separate privileged
interface and should not be in the operator-facing MVP.

### Q3: Agent Commerce Playground demo task?
**Recommendation: Bounded token purchase via allowlisted adapter.**

Specific flow:
1. Operator sets a 0.1 ETH (or equivalent AKM) policy for the agent
2. Operator approves the boundary allowance
3. Agent discovers a simple commerce task (e.g., purchase a test NFT or swap tokens via the allowlisted adapter)
4. UI shows the EIP-712 intent, the settlement transaction, and the exact amounts
5. Operator revokes the allowance — subsequent agent attempts fail closed
6. UI shows the failed attempt and explains why (allowance = 0)

This demonstrates the full Model D loop: policy → allowance → execution → revocation → fail-closed.

### Q4: Escrow in MVP?
**Recommendation: Defer to Phase 2.**

Rationale: Escrow is a separate workflow from the core agent execution loop.
The MVP should nail the allowance manager, policy dashboard, and intent execution.
Escrow UI (create/release/refund) adds significant scope without being on the
critical path for the grant demo or Model D validation.

---

## 10. CI Acceptance Criterion (Per Aegis)

> **No frontend configuration may reference a contract marked deprecated, dead, deferred, or out-of-scope.**

This is implemented as `frontend/src/config.check.ts` — a CI script that fails
if any address in `config.ts` matches the denylist.

**Denylist (auto-generated from decisions):**
- `0xdC3fC3e840b14Ce345638549D0d4617b75cD89b9` — DEPRECATED (G-5)
- `0x7e5095d10a4B71220938b816398918239981030a` — DEAD (PrivacyEngine deferred)

Run: `npx tsx src/config.check.ts` (or integrate into `npm run build`)

---

**Next step:** Review this matrix against actual Solidity interfaces once the
contract candidate is frozen. Do not write UI code until ABIs are regenerated.
