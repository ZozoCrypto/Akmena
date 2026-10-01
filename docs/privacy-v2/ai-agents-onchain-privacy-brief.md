# AI Agents × On-Chain Privacy: Technical Brief

Prepared 2026-09-30. For the Akmena PrivacyEngine redesign (Base, EVM).

---

## 1. Why AI agents need transaction privacy: threat models

Agents differ from human users in ways that make transparency specifically dangerous:

**T1. Strategy leakage (alpha decay).** An agent that trades, bids, or negotiates on-chain reveals its full decision function through its transaction history. Competitors (human or machine) can clone the strategy by replaying the agent's on-chain behavior — no reverse-engineering needed. For agents this is worse than for humans: the agent's edge *is* its policy, and the policy is fully observable. Concrete form: an arbitrage agent's swap sequence, slippage tolerance, and venue selection are all in the clear; a copycat bot can front-run the strategy itself, not just individual trades.

**T2. Payment correlation (operator ↔ counterparty linkage).** Every agent payment links a funding wallet to a recipient. Over time this builds a complete graph: who funds which agents, which agents pay which services, fee flows back to operators. For an "autonomous commerce trust layer" this defeats the purpose — the operator's business relationships, supplier list, and revenue splits become public intelligence. Concrete form: `operator_wallet → agent_wallet → service_provider` chains are trivially clusterable by any indexer.

**T3. MEV / frontrunning of agent intents.** Agents emit economically meaningful transactions on predictable schedules (rebalancing, DCA, settlement of escrows). These are ideal MEV targets: sandwich attacks on DEX swaps, generalized frontrunning of any profitable agent action visible in the mempool. Retail traders lose an estimated 1–5% per swap to sandwich MEV; agents, which transact at machine frequency, compound this into a structural tax. Counter-MEV honeypots (fake tokens engineered to drain MEV bots, e.g. the 2026 JaredFromSubway $7.5–15M drain) show the mempool is actively adversarial — agents are both victims and, if careless with approvals, attack surface.

**T4. Behavioral fingerprinting.** Even without amounts, timing and counterparty patterns identify agents: gas-price bidding behavior, nonce cadence, interaction graphs with specific contracts. An observer can infer an agent's task schedule, its operator's timezone/working hours, and its economic relationships. For agents acting on behalf of principals, this leaks the principal's intent.

Bottom line: for agents, transparency doesn't just leak *value* — it leaks the *decision process itself*, which is the asset.

---

## 2. ERC-8004: what it standardizes, and its privacy dimension

ERC-8004 ("Trustless Agents", draft, proposed 2025-08) defines three on-chain registries:

- **Identity Registry** — each agent is an ERC-721 NFT with a unique `agentId`; `tokenURI` points to a registration file (name, capabilities, endpoints) on IPFS/HTTPS. Portable, indexable with existing NFT tooling.
- **Reputation Registry** — clients submit *signed* feedback (scores 0–100, tags, evidence links). Raw signals on-chain; scoring models built off-chain per platform.
- **Validation Registry** — hooks for third-party verification of agent work: stake-secured re-execution, zkML proofs, or TEE attestation. Least mature of the three.

Deployed on Ethereum mainnet and 30+ EVM chains (early 2026), ~45k agents registered.

**Privacy dimension: effectively none in the spec.** Identity is a *public* NFT by design — discoverability is the point. Reputation feedback is public. The spec deliberately excludes payment mechanisms, reputation formulas, and validation methods. Privacy enters only at the edges:

- **SIWA (Sign In With Agent)** pattern: the agent's signing key never resides in the agent process; signing goes through a separate keyring proxy (e.g. Turnkey). This is key-custody hygiene, not transaction privacy.
- **Validation via TEE** (Oasis ROFL wires ERC-8004 validation to confidential compute): proves *which code ran*, not *what data it saw*.

Implication for Akmena: ERC-8004 solves "who is this agent and should I trust it" — the exact opposite direction from "hide what this agent does." If Akmena adopts ERC-8004 identity, the privacy layer must be designed to *not* undermine it: an agent can have a public identity (for reputation/discovery) while its *payment flows* stay shielded. These are separable concerns; conflating them breaks both.

---

## 3. Private agent-to-agent payments: existing approaches

**RAIL20** — the closest existing prior art. A multi-chain ZK privacy pool **live on Base (chain 8453)**, Arbitrum, and Robinhood Chain, built specifically for agents (Virtuals ACP ecosystem). Design: deposits go into a Poseidon commitment tree; transfers are Groth16 proofs generated client-side and verified on-chain; relayers pay gas so the destination address never touches the funding wallet. On-chain footprint per transfer: one commitment + one nullifier — no sender, no recipient, no amount. Agents hold a shielded balance and pay from it. Protocol spec and source are public (rail20dev/protocol). *This is the design Akmena's PrivacyEngine should be measured against.*

**x402 / Ax402 + SAW (Simple Agent Wallet)** — the dominant *transparent* agent-payment rail. HTTP 402 payment challenges, stablecoin settlement, EIP-3009/Permit2 authorizations. Fast and production-deployed, but amounts, counterparties, and timing are fully public. Privacy is explicitly out of scope.

**MultiHopper (Solana)** — "private programmable routing" for agents: multi-hop payment paths across wallets/contracts without intermediary signing authority, non-custodial, no mixers or commingled funds. Privacy via routing indirection rather than cryptography — weaker unlinkability than a ZK pool, but no trusted setup.

**Canton Network** — DLT with *selective disclosure*: transaction amount hidden from the public; only the two counterparties and designated auditors see it. Settlement is atomic; compliance (AML/KYC) enforced at the contract layer. Relevant as a model for "private but auditable" — privacy is per-observer, not absolute.

**Pattern across all of them:** real agent-payment privacy today = either (a) a ZK shielded pool (RAIL20, Railgun-style), or (b) trusted-intermediary routing with access control (Canton, MultiHopper). There is no production system doing private agent payments on transparent EVM rails without one of these two.

---

## 4. TEE-based agents: what they give, where they break

How TEEs are used for agents:

- **Key custody**: agent signing keys generated and held inside the enclave (Intel SGX, AWS Nitro, AMD SEV); the host operator cannot extract them. E.g. NOVA/Shade Agents (NEAR): group keys derived via HKDF inside the TEE, AES-256-GCM sealed; on-chain contract stores only metadata and attestations.
- **Verifiable execution**: remote attestation proves *a specific measured binary* ran on genuine hardware. Oasis ROFL runs Eliza agents in TEEs and auto-registers them in ERC-8004's validation registry — attestation becomes the trust signal. OpenGradient runs every LLM inference in a TEE and settles a proof on-chain via x402.
- **Confidential inputs**: API keys and secrets injected as end-to-end-encrypted env vars, decrypted only inside the enclave.

**Limits — and they are load-bearing for a privacy design:**

1. **Hardware-vendor trust root.** You replace "trust the chain" with "trust Intel/AWS/AMD." SGX has a long CVE history (Foreshadow, Plundervolt, SGAxe, ÆPIC); each one retroactively breaks confidentiality of everything ever run on affected silicon.
2. **Attestation ≠ correctness.** A TEE proves *which code* ran, not that the code is bug-free or honest. A backdoored agent binary attests just fine.
3. **Operator asymmetry.** Whoever provisions the enclave (cloud account holder) typically controls its lifecycle; a malicious host can still do traffic analysis, timing attacks, and rollback of sealed state.
4. **No on-chain privacy by itself.** A TEE agent that signs transparent transactions leaks everything T1–T4 describe. TEEs protect *data at rest/in use off-chain*; they do nothing for *data published on-chain*. This is the most common architectural error: "our agent runs in a TEE" is cited as privacy while every payment is a public ERC-20 transfer.
5. **Key recovery / availability.** Enclave-sealed keys are bound to the hardware; migration and disaster recovery require explicit (and delicate) provisioning ceremonies.

**Correct composition:** TEE for *agent-side secret management* (shielded-pool spending keys, note plaintexts) + ZK pool for *on-chain settlement privacy*. Neither substitutes for the other.

---

## 5. Confidential intents

The intent model ("I want X outcome" rather than "execute these calls") creates a natural privacy surface: if the *intent* is what gets gossiped and matched, hiding intent contents hides the trade before it exists.

**Anoma** is the reference architecture: intent-centric protocol with privacy-by-default. Intents propagate over an intent gossip network; solvers match them; settlement happens through a Resource Machine with ZKPs and the Multi-Asset Shielded Pool (MASP). Intents can be encrypted or partially revealed per application policy — amounts, asset types, and participant identities stay confidential unless selectively disclosed. The Anoma Protocol Adapter went live on Ethereum mainnet (Nov 2025). Sibling chain Namada runs the MASP in production for shielded cross-chain transfers.

Key ideas transferable to an EVM agent layer:

- **Encrypted intent gossip**: intents are visible to matchmakers only in the dimensions needed for matching (e.g. asset pair) while amounts/counterparties stay sealed until execution.
- **Solver separation**: the party that *matches* an intent need not be the party that *sees* its full contents — ZK proofs can demonstrate matchability without revealing terms.
- **Programmable disclosure**: the intent author controls what each observer class (solver, counterparty, auditor, public) learns. This is strictly more expressive than "public" or "fully shielded."

Caveat: Anoma's full vision requires its own resource machine; on Base/EVM today, the practical subset is *commit-reveal intents with ZK validity proofs* — commit to the intent hash on-chain, reveal terms only to the chosen filler over an encrypted channel, prove in ZK that the fill respected the committed terms.

---

## 6. What a "private settlement" primitive must guarantee (for agents)

For an agent-facing settlement pool on EVM, the properties that matter:

**Must have:**

- **Unlinkability (deposit ↔ withdrawal).** Given a withdrawal, no efficient adversary can determine which deposit funded it, beyond the anonymity-set size. This is the core property the current hash-commitment design lacks: without a ZK membership proof over a commitment tree, deposits and withdrawals are trivially linkable by timing/amount graph analysis.
- **Confidentiality of amounts.** Amounts must live *inside* the commitment (hashed), never in the clear. Variable amounts additionally require either denominated notes (fixed sizes, like Tornado Cash's original design — cheaper circuits, weaker UX) or **range proofs** proving amounts are non-negative and conservation holds without revealing them.
- **Double-spend prevention.** A nullifier scheme: spending a note reveals a deterministic nullifier derived from the note's secret; the contract tracks spent nullifiers. This is what makes the pool *sound* — it is the privacy-preserving replacement for "balance bookkeeping."
- **Conservation of value.** The ZK circuit must prove `sum(inputs) = sum(outputs) + fee` inside the proof. The contract verifies the proof, not the amounts. Without this, the pool is a mint.
- **Sybil-resistant anonymity set.** Privacy scales with the number of *indistinguishable* notes. A pool with 3 deposits gives ~1.5 bits of anonymity. Deposit incentives or a shared multi-asset pool (MASP-style) matter more than circuit cleverness.

**Must remain auditable (selective, not public):**

- **Viewing keys.** The note owner can grant a third party (auditor, operator, regulator) the ability to decrypt *their* notes without affecting others' privacy. Railgun and the EthSystems shielding pattern both standardize this.
- **Proof of solvency / reserves.** The pool contract's token balance is public; anyone can verify `pool_balance ≥ sum of unspent commitments` only if commitments are binding — which is why the commitment must bind the amount (the exact bug class in Akmena's current design, where the commitment did not record the amount).
- **Compliance hooks without backdoors.** Privacy Pools (0xbow) model: an Association Set Provider (ASP) attests that a deposit isn't from a sanctioned source; the withdrawal circuit proves inclusion in the "clean" set without revealing which deposit. This gives *regulatory auditability* without a global viewing key.

**Agent-specific additions:**

- **Delegated proving.** Agents are headless; proof generation must run in the agent's runtime (or its TEE) without human interaction. Proving time and memory (Groth16 on a Poseidon tree of depth ~20) must fit the agent's compute budget — or proving must be outsourcable to an untrusted prover (proofs are self-verifying, so outsourcing is safe as long as note secrets never leave the agent).
- **Gas abstraction.** The withdrawing agent may hold no native token; relayers (as in RAIL20) submit the withdrawal and take a fee from the withdrawn amount. The relayer learns timing and recipient but not the sender — this residual leak must be documented, not ignored.
- **Policy compatibility.** The privacy pool must compose with Akmena's policy boundary: spending limits, allowlists, and admission criteria apply to *shielded* flows too, or the pool becomes a policy bypass. The natural construction: the policy check happens at deposit *into* the pool and at withdrawal *to* a target, with the shielded interior unobserved.

---

## What "good" looks like — design sketch for the PrivacyEngine rewrite

1. **ZK note pool, not hash commitments.** Incremental Poseidon Merkle tree of note commitments; Groth16 (or Plonk) verifier on-chain; nullifier set for double-spend prevention. This is the RAIL20/Railgun/Tornado architecture — proven, audited patterns exist.
2. **Amounts inside commitments + conservation circuit.** Every state transition proves value conservation in zero knowledge. The current design's failure (commitment not binding the amount) must be structurally impossible, not just patched.
3. **Fixed denominations first, arbitrary amounts later.** Denominated notes need no range proofs — simpler circuits, smaller trusted setup, faster audit. Arbitrary amounts come with range-proof circuits in a second iteration.
4. **Viewing keys from day one.** The operator-auditability story is what separates "privacy infrastructure" from "mixer."
5. **TEEs hold note keys, never substitute for the pool.** Agent spending keys and note plaintexts live in the agent's TEE (or MPC); on-chain privacy comes from the ZK pool alone.
6. **Benchmark against RAIL20 on Base.** It is live on the same chain, agent-focused, and open-source. Any design decision that makes Akmena's pool weaker than RAIL20's needs a written justification.

## Notes on sources

- The Ethereum whitepaper establishes the transparent-by-default execution model (all state transitions are publicly verifiable); it contains no privacy construction. Privacy on Ethereum has always been an overlay concern — which is why every serious approach above is either a ZK overlay (pools), a separate execution environment (TEEs, Aztec), or a new state model (Anoma/Namada).
- ERC-8004 is draft status; the Validation Registry is the least deployed component. Treat TEE/zkML validation claims as "standardized hooks," not "available infrastructure."
