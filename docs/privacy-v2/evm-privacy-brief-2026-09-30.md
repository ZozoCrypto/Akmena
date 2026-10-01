# On-chain privacy for EVM — technical brief
**Date:** 2026-09-30 · **Purpose:** design input for an EVM private pool (Base Sepolia target)
**Legend:** SOURCE-CONFIRMED = verified via tool this session · DOCUMENTED = public codebase/paper, verifiable at cited location · ASSUMPTION = inference/estimate, do not treat as measured

---

## 0. Decision table

| Approach | Unlinkability | Amount hiding | Needs ZK | Needs trusted setup | On-chain verify gas | Compliance story |
|---|---|---|---|---|---|---|
| Tornado Cash (fixed-denom pools) | Yes (per-denom set) | Yes (fixed) | Groth16 | Per-circuit | ~250k | None |
| Privacy Pools (0xbow) | Yes (association subset) | Yes (fixed) | Groth16 | Per-circuit | ~250k + ASP check | Association sets, ragequit |
| Stealth addresses (EIP-5564) | Recipient only | No | No | No | ~30–60k (plain transfer + event) | N/A (not a pool) |
| Railgun (shielded UTXO) | Yes | Yes (encrypted notes) | Groth16 | Per-circuit | ~250k+ | PPOI (opt-in) |
| Hash-preimage "pool" (no ZK) | **No** | No | No | No | ~50k | N/A |

---

## 1. Tornado Cash model

### 1.1 Mechanics (DOCUMENTED — tornado-cash/tornado-core)

**Deposit.** User generates `secret`, `nullifier` (each 31 random bytes) off-chain.
`commitment = Pedersen(nullifier, secret)` is sent on-chain; the secret note
(`tornado-<denom>-<chainId>-<secret>-<nullifier>`) never touches chain.

```solidity
// Mixer.sol (ETH pool)
function deposit(bytes32 _commitment) external payable nonReentrant;
function withdraw(
    bytes calldata _proof,
    bytes32 _root,
    bytes32 _nullifierHash,
    address payable _recipient,
    address payable _relayer,
    uint256 _fee,
    uint256 _refund
) external payable nonReentrant;
```

- `deposit` inserts the commitment into an **incremental Merkle tree, depth 20**
  (max 2²⁰ ≈ 1M leaves), hashed with **MiMCSponge** (SNARK-friendly). The
  contract stores only the current root + a **root history of the last 100 roots**
  (DOCUMENTED — `ROOT_HISTORY_SIZE = 100`; lets a proof generated against a
  slightly stale root still verify).
- `withdraw` checks: `_root` is a known root, `_nullifierHash` unspent, then
  `verifier.verifyProof(_proof, [_root, _nullifierHash, _recipient, _relayer, _fee, _refund])`.
  On success it marks the nullifier spent and pays `denomination - _fee` to
  `_recipient`, `_fee` to `_relayer`.

**Circuit** (`withdraw.circom`, Groth16 over BN254), private inputs: `nullifier`,
`secret`, `pathElements[20]`, `pathIndices[20]`; public inputs: `root`,
`nullifierHash`, `recipient`, `relayer`, `fee`, `refund`. Constraints prove:
(1) `commitment = Pedersen(nullifier, secret)` is a leaf with a valid Merkle
path to `root`; (2) `nullifierHash = MiMCSponge(nullifier)` matches the public
input. **Order of tens of thousands of R1CS constraints** (MiMC path dominates)
— provable client-side in seconds (ASSUMPTION — order-of-magnitude estimate
consistent with public benchmarks).

### 1.2 Why fixed denominations matter

If deposits could be arbitrary amounts, withdrawal amount ≈ deposit amount
uniquely identifies the depositor (amount correlation). Fixed denominations
(0.1 / 1 / 10 / 100 ETH pools) make every withdrawal identical on-chain, so
the **anonymity set = all deposits in that denomination's pool**. Cost: the set
fragments per denomination; small pools have weak anonymity. (DOCUMENTED)

### 1.3 Relayer mechanism

Problem: withdrawing to a fresh address requires gas, and funding that address
creates an on-chain link to the withdrawer. Solution: a third-party **relayer**
submits the tx and takes `_fee` from the withdrawal. Security property: the
proof's public inputs bind `(recipient, relayer, fee)` — the relayer **cannot
redirect funds or inflate its fee**; any tampering invalidates the proof.
(DOCUMENTED)

### 1.4 Operational history — what worked, what broke

- **Worked:** immutability. OFAC sanctioned the contracts (Aug 2022); a Nov 2024
  US appeals ruling held immutable contracts aren't sanctionable "property";
  OFAC delisted Mar 2025 (SOURCE-CONFIRMED). The contracts kept operating
  throughout — sanctions hit front-ends, RPCs, and relayers, not the bytecode.
- **Worked:** client-side proving (snarkjs in browser); per-circuit MPC trusted
  setup via the perpetual Powers-of-Tau ceremony.
- **Broke:** the relayer ecosystem — most relayers shut down under sanctions
  pressure, leaving UX degraded but the protocol functional. Timing correlation
  (deposit→quick withdraw) and small anonymity sets deanonymized careless users.
  Roman Storm convicted Aug 2025 on unlicensed-money-transmission conspiracy;
  money-laundering/sanctions counts deadlocked (SOURCE-CONFIRMED).
- Net: the cryptography held; the **social/operational layer** (relayers, timing
  discipline, legal exposure of operators) was the failure surface.

---

## 2. Privacy Pools (0xbow)

### 2.1 What changed vs Tornado Cash (SOURCE-CONFIRMED)

Same Groth16 deposit/withdraw core, plus a **second Merkle tree**: the
**Association Set Provider (ASP) tree**. Core contracts
(`0xbow-io/privacy-pools-core`): `Entrypoint` (shared `associationSets` tree
across all pools — depth up to 2³² leaves per the team's audit response),
per-asset pool contracts, `ASP` contracts that vet deposits.

- Deposits are screened (KYT-style checks); only vetted commitments enter an
  **association set**.
- Withdrawal proves membership in **both** the global deposit tree **and** the
  chosen association set — i.e. "my funds come from *this* vetted subset," not
  merely "my funds are in the pool." The association-set root is an additional
  public input to the withdraw circuit.
- **Ragequit:** if your deposit is later removed from the set, you can withdraw
  back to your original deposit address (no one else can take it).
- Association sets are **dynamic**: illicit deposits can be removed without
  disturbing others.

### 2.2 Status (SOURCE-CONFIRMED)

- Launched on Ethereum mainnet **31 Mar 2025**; Vitalik made an early deposit;
  initial cap **1 ETH** per deposit, raised after battle-testing.
- Oxorio audit is public in the repo; team responses included.
- Brevis × BNB Chain "Intelligent Privacy Pool" (0xbow collaboration) **launched
  early 2026** — extends the model with ZK-proven eligibility (on-chain
  provenance / exchange-account status) before private transfer.

### 2.3 Design note

The anonymity set is now *chosen*, not maximal: you trade set size for a
compliance narrative ("not mixed with known-bad funds"). For a design that must
survive regulatory scrutiny, this is the current state of the art; for maximal
unlinkability, plain Tornado-style sets are larger.

---

## 3. Stealth addresses — EIP-5564 + EIP-6538

### 3.1 Protocol (SOURCE-CONFIRMED — ethereum/app-enablement-resources, updated ~Aug 2026)

1. **Recipient** generates a *spending* keypair and a *viewing* keypair; publishes
   both public keys as a **stealth meta-address** via the **ERC-6538 registry**
   (or out of band).
2. **Sender** fetches the meta-address, generates a fresh **ephemeral** keypair.
3. Sender computes `shared_secret = ECDH(ephemeral_priv, viewing_pub)` (secp256k1,
   scheme ID 1), derives a 1-byte **view tag** = `H(shared_secret)[0]`, and the
   **stealth address** with public key `P_stealth = P_spend + H(shared_secret)·G`.
4. Sender pays the stealth address and emits the ephemeral public key + view tag
   through the singleton **ERC-5564 Announcer** contract (an event; no custody).
5. Recipient **scans** announcements with the viewing key; the view tag rejects
   255/256 non-matches cheaply; full derivation runs on the remainder.
6. Recipient derives `stealth_priv = spend_priv + H(shared_secret)` and spends
   normally.

Key EIP-5564 event (DOCUMENTED — EIP text):
```solidity
event Announcement(
    uint256 indexed schemeId,
    address indexed stealthAddress,
    address indexed caller,
    bytes ephemeralPubKey,
    bytes metadata
);
```
ERC-6538 registry: `registerKeys(uint256 schemeId, bytes stealthMetaAddress)`.
**No circuits, no trusted setup, no pooled custody** — the on-chain surface is a
registry (storage) + announcer (events); all crypto is client-side secp256k1.

### 3.2 What it provides — and what it doesn't

- **Provides: recipient unlinkability.** Nothing on-chain links the one-time
  stealth address to the recipient's known address or meta-address.
- **Does NOT provide:** amount privacy (value is plaintext), sender privacy
  (sender's address pays the stealth address visibly), timing privacy, or any
  anonymity *set* (each payment stands alone).
- **Scanning leak (SOURCE-CONFIRMED):** whoever serves the announcement log sees
  which announcements a wallet fetches and from which IP — scanning through a
  hosted RPC hands the link to the endpoint even though the chain never records
  it. A leaked viewing key reveals *which* payments belong to the recipient
  (not the funds — spending key stays safe).
- Verdict: the cheapest real privacy primitive (weeks, not quarters), but it
  hides **who receives**, nothing else. Composable *under* a pool (private
  withdrawals to stealth addresses), not a substitute for one.

---

## 4. ZK proof systems on EVM

### 4.1 Verifier economics (SOURCE-CONFIRMED — 7blocklabs, 2026)

| System | Verify gas (typical) | Proof size | Trusted setup | Notes |
|---|---|---|---|---|
| **Groth16** (BN254) | ~207.7k fixed + ~7.16k per public input → **~220–250k** for a 3–6-input withdraw | 256 B (128 B compressed) | **Per-circuit** MPC | Cheapest verify; used by Tornado, Railgun, Privacy Pools |
| **PLONK/KZG** | ~300–350k | ~0.8–1.2 KB | Universal SRS | Used by Aztec, zkSync |
| **FFLONK** | ~236k | small | Universal | Groth16-class gas without per-circuit ceremony |
| STARK-only | ~2M+ | 50–200 KB | Transparent | Impractical on L1; wrapped to Groth16 in practice |

Pairing cost driver: `45000 + 34000·k` gas for k pairings (EIP-197); Groth16
verifiers batch to a single pairing check. BN254 precompiles (EIP-196/197/198)
exist on every EVM-equivalent chain — **Base Sepolia included** (DOCUMENTED).
EIP-2537 (BLS12-381 precompiles) shipped in Pectra (SOURCE-CONFIRMED), but
Groth16/BN254 remains the cheapest path.

### 4.2 Toolchains

- **circom + snarkjs/rapidsnark:** most mature for membership circuits
  (`circomlib` has Merkle-tree templates); browser proving in the hundreds of
  ms–seconds for hash circuits (SOURCE-CONFIRMED). Costs: **GPL-3.0**
  (snarkjs/rapidsnark) and a **per-circuit trusted setup** (can reuse the
  perpetual Powers-of-Tau for phase 1; production wants a circuit-specific
  phase-2 MPC).
- **Noir + UltraHonk (bb.js):** Apache-2.0, better DX, browser proving via
  multithreaded WASM; verifier ~300–600k gas (SOURCE-CONFIRMED). Aztec's stack.
- **halo2:** no direct EVM verifier story (BLS12-381 based; pre-Pectra this was
  a blocker). Not the pick for an on-chain EVM verifier today.

### 4.3 Is a Merkle-membership circuit practical on Base Sepolia today?

**Yes.** Concrete recipe: adapt Tornado's `withdraw.circom` (depth-20 MiMC
tree), run Powers-of-Tau + phase-2, `snarkjs zkey export solidityverifier`,
deploy the verifier to Base Sepolia (plain contract deployment — BN254
precompiles are live there), wire `withdraw()` to check root history +
nullifier + `verifyProof`. Expected withdrawal cost ≈ 220–260k gas; proving is
client-side and needs no chain interaction. For a fixed, small circuit that
won't change often, **circom/Groth16 is the battle-tested choice**; pick Noir
only if you expect frequent circuit iteration (universal setup) or need its DX.

---

## 5. Railgun / Aztec (notes)

### Railgun (DOCUMENTED — public design; status details NOT-ASSESSED this session)

- **UTXO shielded balances**, not fixed denominations. Deposits ("shielding")
  create encrypted notes: `commitment = H(token, amount, recipient viewing key,
  randomness)` appended to a per-chain Merkle tree; amounts/recipients hidden
  inside the note, decryptable by the owner's viewing key.
- Spends consume notes and create new ones, publishing **nullifiers**;
  Groth16 (BN254) proofs attest to note membership + balance conservation +
  correct nullifier derivation (eth-systems map lists Railgun as a Groth16
  user — SOURCE-CONFIRMED).
- Private DeFi: shielded balances can interact with external contracts via
  adapters without unshielding.
- Gas abstraction via a **broadcaster** network (relayer analogue).
- Compliance: **Private Proofs of Innocence (PPOI)** — opt-in proof that your
  funds are not in a published set of known-bad deposits (Vitalik publicly
  used/wrote about this in 2023).

### Aztec (DOCUMENTED — public design; mainnet status NOT-ASSESSED this session)

- Full **UTXO note model at the L2 level**: every contract's private state is a
  set of notes; commitments are **siloed** (bound to the contract address) so
  notes can't be replayed across apps.
- Nullifiers derived from a note's nullifier secret; spent notes can never be
  respent. Local proving in the **PXE** (Private eXecution Environment);
  circuits written in **Noir**, proven with **Honk (PLONK-family over KZG)**.
- Aztec is an L2, not a pool contract — the privacy model is architectural
  (private execution), which is why it needs its own chain rather than a
  verifier contract.

---

## 6. Minimal honest primitive set — and what breaks without ZK

### 6.1 Minimal primitives for real unlinkability in an EVM pool

1. **Hiding + binding commitment:** `C = H(secret, nullifier, …)` with a
   SNARK-friendly hash (Pedersen/Poseidon). Hiding: `C` reveals nothing about
   the preimage. Binding: you can't find a second preimage.
2. **Append-only accumulator:** incremental Merkle tree (depth 20 is the
   field standard); contract stores current root **plus root history**
   (~100 roots) so proofs survive the blocks between proving and mining.
3. **Nullifier uniqueness:** publish `nullifierHash = H(nullifier)` at spend;
   `mapping(nullifierHash => spent)` prevents double-spend *without* revealing
   which commitment it came from.
4. **ZK membership circuit** proving, for public inputs
   `(root, nullifierHash, recipient, relayer, fee)`:
   - ∃ `(secret, nullifier, path)` with `leaf = C(secret, nullifier)` in the
     tree at `root`;
   - `nullifierHash` is correctly derived from the same `nullifier`;
   - `recipient/relayer/fee` are bound so intermediaries can't redirect.
5. **On-chain Groth16 verifier** + withdrawal logic: known-root check,
   unspent-nullifier check, proof verification, then payment.
6. **Fixed denomination per pool** (or hidden-amount UTXO with range proofs) —
   otherwise amounts correlate deposits to withdrawals.
7. **Relayer / gas abstraction** with the fee bound in the proof — otherwise the
   withdrawal address needs funding, creating an on-chain link.
8. **(Compliance option)** Association-set tree + second membership proof
   (Privacy Pools model).

Omit any one of 1–7 and the unlinkability claim is false, not weakened.

### 6.2 What breaks if you skip ZK and use hash-preimage reveal

Suppose `withdraw(secret, nullifier)` and the contract checks
`H(secret, nullifier) ∈ tree`:

- **Unlinkability → zero.** Anyone (not just the contract) recomputes the
  commitment and locates the exact deposit leaf. The "pool" is a delayed public
  transfer. Timing analysis isn't even needed.
- **Theft by mempool front-running.** The preimage *is* the authorization. An
  attacker copying `(secret, nullifier)` from the mempool can submit the same
  call with *their own* recipient — the contract cannot distinguish the thief
  from the owner, because both present a valid preimage. (Binding the recipient
  at deposit time, e.g. `C = H(secret, nullifier, recipient)`, fixes theft but
  destroys the fresh-address withdrawal that unlinkability requires — the
  recipient is then fixed and linkable at deposit time.)
- **What still works:** double-spend prevention (nullifier list) and amount
  integrity. I.e., you keep the accounting properties and lose *all* the
  privacy properties.
- **Fee/relayer binding is impossible** without revealing: a relayer's fee can't
  be committed to without either ZK or a trusted relayer.

### 6.3 Direct implication for the current PrivacyEngine design

The present `depositPrivateEscrow(commitment)` / settlement flow records a
commitment and later settles against it — with **no membership proof and no
nullifier indirection**, the settlement transaction is trivially linkable to
the deposit by the commitment value itself. It has the accounting half
(commitment recorded, amount now recorded post-fix) but **none of the
unlinkability half**. To get real unlinkability, the design needs primitives
1–5 above at minimum: a Merkle tree of commitments, a nullifier scheme, and a
Groth16 membership circuit with a deployed verifier — all practical on Base
Sepolia today per §4.3.
