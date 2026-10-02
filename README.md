# Akmena

**The trust layer for AI-agent autonomous commerce on Base.**

Akmena lets AI agents transact on-chain with cryptographic authorization, operator-defined spending policies, and zero pooled custody. Operators keep their funds. Agents get bounded, revocable spending power.

## Why Akmena?

Traditional approaches to agent commerce fail in predictable ways:

| Approach | Problem |
|----------|---------|
| Give the agent a private key | Unbounded spend; key compromise = total loss |
| Pooled escrow contracts | Honeypot; single point of failure |
| Off-chain authorization | No on-chain verifiability; trust required |

**Akmena's answer: Model D operator custody.** The operator's tokens never leave their wallet until the moment of settlement. The protocol *pulls* exactly what's authorized via ERC20 allowance — no pre-deposited pool, no honeypot, no trust in the protocol with custody.

## How It Works

```
┌──────────┐     1. Set policy      ┌──────────────────┐
│ Operator │ ────────────────────► │ AkmenaPolicy     │
│ (wallet) │   (daily limit,       │ Boundary         │
└──────────┘    allowlist)         └────────┬─────────┘
      │                                      │
      │ 2. Grant allowance                   │ 3. Agent submits
      │    (revocable anytime)               │    signed intent
      ▼                                      ▼
┌──────────┐                          ┌──────────────┐
│ Operator │                          │   Settlement │
│  Wallet  │ ◄── 4. Pull exactly ──── │  (atomic:    │
│ (funds   │     what's authorized    │   check →    │
│  stay    │                          │   pull →     │
│  here)   │ ── 5. Push to target ──► │   push)      │
└──────────┘                          └──────────────┘
```

1. **Operator sets a spending policy** for an agent: daily limit, per-transaction max, allowlisted adapters, authorized assets.
2. **Operator grants an ERC20 allowance** to the boundary. Revocable at any time — revocation is fail-closed.
3. **Agent signs an intent** (EIP-712 v2) specifying target, calldata, asset, and amount.
4. **Boundary verifies**: signature, nonce, policy, time window, adapter allowlist, allowance, and headroom — then pulls exactly `intent.amount` from the operator.
5. **Settlement is atomic**: check → pull → push → external call. Any failure reverts everything.

## Key Properties

- **No pooled custody** — operator funds stay in the operator's wallet until settlement
- **Fail-closed revocation** — revoking allowance instantly stops the agent; in-flight intents revert cleanly
- **Saturating arithmetic** — limit checks use saturating headroom; never `Panic(0x11)`, always clean `PolicyExceeded()`
- **EIP-712 v2 domain** — signatures are domain-separated by chain and contract; v1 signatures are invalid
- **Replay protection** — nonces are consumed on execution; each intent executes at most once
- **Reentrancy guarded** — EIP-1153 transient locks on settlement and escrow paths
- **Governance-ready** — 24h timelock for allowlist changes, 3-of-5 Safe for emergency removal, separate pause guardian

## Quickstart

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js 18+ (for the SDK)

### Build and Test

```shell
# Clone
git clone https://github.com/ZozoCrypto/Akmena.git
cd Akmena

# Build
forge build

# Run the full test suite (unit)
forge test --no-match-path "test/invariant/*"

# Run invariant tests
forge test --match-path "test/invariant/*"
```

### Deploy to Base Sepolia

```shell
# Deploy core architecture (Core + Boundary + Escrow + Token)
forge script script/DeployCoreArchitecture.s.sol \
  --rpc-url https://sepolia.base.org \
  --broadcast --verify
```

See `DEPLOYMENT_RUNBOOK_DRAFT.md` for the full mainnet deployment procedure.

### Use the TypeScript SDK

```typescript
import { AkmenaClient } from '@akmena/sdk';
import { createWalletClient, http } from 'viem';

const client = new AkmenaClient({
  chain: baseSepolia,
  boundaryAddress: '0x...',
  walletClient,
});

// Operator: set a spending policy for an agent
await client.setAgentPolicy({
  agent: '0xAgentAddress...',
  asset: '0xTokenAddress...',
  dailyLimit: parseEther('1000'),
  maxSpendPerTransaction: parseEther('100'),
});

// Operator: grant allowance (revocable anytime)
await client.approveBoundary({
  asset: '0xTokenAddress...',
  amount: parseEther('1000'),
});

// Agent: sign and submit an intent
const intent = await client.createIntent({
  target: '0xAdapterAddress...',
  asset: '0xTokenAddress...',
  amount: parseEther('10'),
  payload: '0x...', // encoded call
});
await client.executeIntent(intent);
```

See `packages/sdk/` for full API documentation.

## Architecture

```
src/
├── core/               # AkmenaCore — registry, pause, module discovery, deployer
├── authorization/      # PolicyBoundary — settlement engine, spending policies
│                       # ExecutionAuthorization — EIP-712 v2 signature verification
├── economics/          # EscrowEngine — buyer-funded escrows with transient locks
├── token/              # AkmenaToken (AKM) — vanilla OZ ERC20, the reference asset
├── libraries/          # Shared accounting and proof libraries
└── storage/            # Diamond-pattern storage layouts
```

**Protocol Rule #1:** Lower layers must never know that upper layers exist. Each layer has clear responsibilities, minimal dependencies, stable interfaces, and independently testable behavior.

## Security

Akmena is developed under a 16-phase security campaign (R0–R15):

- **R0–R7:** Threat modeling, architecture review, auth/accounting/escrow analysis, cross-module attacks, governance review
- **R8:** Invariant testing (Foundry)
- **R9:** Fuzzing (Medusa — 100k+ calls, zero failures)
- **R10:** Mutation testing (Gambit)
- **R11:** Formal verification (Halmos — symbolic properties)
- **R12:** Base Sepolia fork tests
- **R13:** SDK adversarial testing
- **R14:** Full regression (850+ tests)
- **R15:** Independent audit (pending)

**Current status:** See `MAINNET_READINESS_CHECKLIST.md` for the live gate-by-gate status. All findings are tracked until disproven with evidence or fixed and retested.

### Security Properties (Proven)

| Property | Evidence |
|----------|----------|
| V-0 drain impossible by construction | `V0_ClosedByConstruction.t.sol` — boundary pulls from attacker, no pool to drain |
| Zero-value DoS patched | `GAP1_RegressionVerify.t.sol` — 10 spam intents leave `totalSpentToday = 0` |
| Allowance revoked mid-flight → clean revert | Phase 3 adversarial battery |
| No overdraft on concurrent intents | Phase 3 adversarial battery |
| Reentrant adapter blocked | `Attack_SmartAgentReentrancy.t.sol` — transient guard |
| EIP-712 v2 domain separation | `EIP712V2Fork.t.sol` — 3/3 on Base Sepolia fork |

### Bug Bounty

A bug bounty program will be announced before mainnet. Critical findings: please report responsibly via [security contact].

## Governance

| Role | Powers | Holder (target) |
|------|--------|----------------|
| Deployer | Pause/unpause, guardian rotation, module registry. Transferable via two-step. | → Timelock (post G-7) |
| Allowlist Admin | Add/remove adapters and admitted tokens (slow path) | 24h TimelockController |
| Emergency Admin | Remove adapters/tokens only (fast path, no delay) | 3-of-5 Safe |
| Pause Guardian | Pause only. Cannot unpause. | Operational key |

See `G7_GOVERNANCE_BRIEF.md` for the full governance design.

## Contracts

### Base Sepolia (testnet)

| Contract | Address |
|----------|---------|
| AkmenaPolicyBoundary (legacy) | `0xdC3fC3e840b14Ce345638549D0d4617b75cD89b9` ⚠️ **DEPRECATED** |

> **Note:** The legacy Sepolia deployment is **DEPRECATED** per Elijah 2026-10-02 (Decision G-5: ABANDON). Do not use for new tests. Fresh deployment addresses will be published in `deployments/` after the G-7 governance migration.

### Base Mainnet

Not yet deployed. See `MAINNET_READINESS_CHECKLIST.md`.

## For Base Builders

Akmena is built for the Base ecosystem:

- **AI-agent commerce** — the missing trust layer for autonomous agents transacting on-chain
- **Operator custody** — no pooled funds means no honeypot; aligns with Base's security-first ethos
- **Developer-friendly** — TypeScript SDK, clear ABIs, comprehensive docs
- **Gas-efficient** — transient reentrancy locks (EIP-1153), saturating arithmetic, minimal storage

**Ideas for builders:**
- Agent marketplaces with bounded spending policies
- Autonomous DeFi strategies with revocable allowances
- AI-powered treasury management with daily limits
- Pay-per-call API monetization for agents

## Documentation

| Document | Description |
|----------|-------------|
| `MAINNET_READINESS_CHECKLIST.md` | Live gate-by-gate readiness status |
| `G7_GOVERNANCE_BRIEF.md` | Governance design and migration plan |
| `R15_REVIEW_PACKAGE.md` | Independent audit scope (pending) |
| `DEPLOYMENT_RUNBOOK_DRAFT.md` | Deployment procedure |
| `INCIDENT_RESPONSE_RUNBOOK_DRAFT.md` | Incident response |
| `NEXT_PHASE_READINESS_ASSESSMENT.md` | Latest security assessment |
| `SLITHER_TRIAGE.md` | Static analysis triage |

## Contributing

We welcome contributions, especially:

- Additional fuzzing harnesses and invariant properties
- SDK improvements and new language bindings
- Documentation and tutorials
- Security research (see Bug Bounty above)

Please read the security policy before submitting PRs that touch `src/`.

## License

MIT — see `LICENSE`.

---

**Built with rigor. Audited with paranoia. Designed for agents.**

*Akmena — from the Greek ἀκμή (akmē): the peak, the prime, the moment of highest development.*
