# Akmena — Base Builder Grant Application (DRAFT)

**Status:** DRAFT — for review after frontend completion. Do not submit.
**Date:** 2026-10-01

---

## Project Name

Akmena — The trust layer for AI-agent autonomous commerce on Base.

## One-Liner

Give AI agents bounded, revocable spending power without giving them your private keys or pooling funds in a honeypot.

## Problem

AI agents need to transact on-chain. Current approaches fail:

1. **Give the agent a private key** → Unbounded spend. Key compromise = total loss. No sane operator does this.
2. **Pooled escrow/allowance contracts** → Honeypot. Every agent's funds in one place. Single point of failure.
3. **Off-chain authorization** → No on-chain verifiability. Requires trusting the operator's infrastructure.

The result: AI agents — the most exciting new user class for crypto — cannot safely transact. This blocks the entire agent-commerce economy.

## Solution

**Akmena Model D: Operator Custody Settlement.**

The operator's tokens never leave their wallet until the moment of settlement. The protocol *pulls* exactly what's authorized via ERC20 allowance:

```
Operator sets policy (daily limit, allowlist) 
    → Operator grants revocable allowance 
    → Agent signs intent (EIP-712) 
    → Protocol verifies + pulls exactly intent.amount 
    → Atomic settlement
```

**Key insight:** There's no pool to drain. The "V-0 drain" — the classic attack on allowance-based systems — is impossible by construction because the boundary pulls from the attacker's own wallet.

It's like giving your AI assistant a corporate card with a spending limit, instead of your bank vault key.

## Why Base?

1. **Agent commerce needs low fees.** Base's L2 economics make agent micro-transactions viable. A $0.50 agent purchase can't cost $5 in gas.
2. **Base is where consumers meet crypto.** Agent commerce is consumer crypto — buying, selling, subscribing, tipping — all on-chain.
3. **Security ethos alignment.** Base prioritizes security. Our "audited with paranoia" development process (16-phase campaign, 850+ tests, formal verification) matches.

## Technical Highlights

### Novel Architecture
- **Zero pooled custody** — no honeypot, no TVL to attack
- **Fail-closed revocation** — revoke allowance, agent stops instantly
- **Saturating arithmetic** — clean `PolicyExceeded()`, never `Panic(0x11)`
- **EIP-712 v2** — domain-separated signatures, v1 invalid
- **EIP-1153 transient locks** — gas-efficient reentrancy protection

### Security Rigor (Unusual for the Space)
Most projects: "We ran Slither and got a PDF."
Akmena: 16-phase campaign (R0–R15):
- 850+ Forge tests (unit + invariant)
- 100,000+ Medusa fuzz calls, zero failures
- Mutation testing (Gambit)
- Formal verification (Halmos, 13 symbolic properties)
- Base Sepolia fork tests
- Independent audit (R15, pending)

All findings tracked until disproven with evidence or fixed and retested. Full evidence in repo.

### Developer Experience
- TypeScript SDK (`@akmena/sdk`) with viem
- Python SDK
- Clear ABIs, NatSpec throughout
- Comprehensive docs and runbooks

## Roadmap

### Phase 1: Security Hardening (Current)
- [x] GAP-1 patched (zero-value DoS)
- [x] GAP-3 hardened (confused deputy → target allowlist)
- [x] Deployer transferability (enables G-7)
- [ ] Full test suite re-verification at HEAD
- [ ] Medusa re-run with native path coverage
- [ ] R15 independent audit

### Phase 2: Testnet Launch (Base Sepolia)
- [ ] G-7 governance migration (24h timelock, 3-of-5 Safe, guardian)
- [ ] Deployment rehearsal (local → Sepolia)
- [ ] **Agent Commerce Playground** (demo dApp)
- [ ] Agent Starter Kit (template repo)

### Phase 3: Mainnet (Base)
- [ ] Independent audit complete
- [ ] Mainnet deployment with full governance
- [ ] Bug bounty program
- [ ] Builder onboarding

## The Demo: "Agent Commerce Playground"

**Something special** — not a slide deck, a live agent doing commerce:

1. User connects wallet as **operator** on Base Sepolia
2. User sets a spending policy: "Agent can spend up to 0.1 ETH/day on NFT purchases"
3. User gives the agent a task: "Buy the cheapest Azuki under 0.05 ETH"
4. **The AI agent reasons**, finds listings, signs intents, and settles on-chain
5. User watches settlements happen in real-time with full cryptographic verification
6. User clicks **"Revoke"** — the agent's next intent reverts cleanly. Fail-closed.

This demonstrates the core value prop in 60 seconds: bounded autonomy, cryptographic guarantees, instant revocation.

## Grant Ask

**Amount:** [TBD — based on Base builder grant tiers]

**Use of funds:**
- 40%: Security — R15 independent audit, bug bounty seed
- 30%: Development — Agent Commerce Playground, Starter Kit, SDK polish
- 20%: Deployment — Mainnet deployment costs, governance setup (Safe, timelock)
- 10%: Documentation — Tutorials, builder guides, video walkthroughs

**Milestones:**
1. R15 audit commissioned (month 1)
2. Sepolia deployment + Playground live (month 2)
3. Mainnet deployment with governance (month 3-4, post-audit)
4. 10 builder projects using Akmena SDK (month 6)

## Team

**Elijah** — Founder. Building Akmena as a serious monetary protocol, not a token project. Security-first development philosophy: "If it can move value, it gets attacked on purpose first."

**Development approach:** AI-assisted with rigorous human oversight. Every claim backed by evidence. Every finding tracked until resolved.

## Links

- GitHub: https://github.com/ZozoCrypto/Akmena
- Docs: [in repo]
- Demo: [post-frontend]

## Why We'll Succeed

1. **Real problem:** Agents can't transact safely. This blocks a huge market.
2. **Novel solution:** Operator custody is a genuine architectural insight, not a fork.
3. **Security credibility:** Our evidence-first approach stands out in grant applications.
4. **Base alignment:** Low fees + consumer focus + security ethos = perfect fit.
5. **Execution:** 850+ tests, working code, clear roadmap. Not vaporware.

---

**Appendix: Security Evidence Summary**

| Campaign | Result |
|----------|--------|
| Unit tests | 850+ pass |
| Invariant tests | 30/30 pass |
| Medusa fuzz | 100k+ calls, 0 failures |
| Mutation | 100% effective |
| Halmos | 13/13 properties |
| Fork tests | 15/15 on Base Sepolia |
| Slither | 6 Highs triaged |

Full details: `MAINNET_READINESS_CHECKLIST.md`, `NEXT_PHASE_READINESS_ASSESSMENT.md`
