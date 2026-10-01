# Privacy v2 — Primary Source Verification
**Date:** 2026-10-01 · **Author:** Muse (research only, no code changes)
**Purpose:** Ground the undecided privacy direction (Akmena-owned pool vs. existing rail vs. defer)
in primary sources. Elijah's standing direction: do not pitch the current pool to Base; do not
treat v2 as a win until compliance, policy integration, and anonymity-set realities are addressed.

Evidence labels: **SOURCE-CONFIRMED** (primary source read) / **NOT-ASSESSED** (not verified).

---

## 1. Railgun / RAIL20 on Base — SOURCE-CONFIRMED: NOT SUPPORTED

**Primary source:** https://docs.railgun.org/ (official Railgun documentation, read 2026-10-01)

**Quote:**
> "RAILGUN is code that exists on every Ethereum node. It's a privacy system built directly
> on-chain for **Ethereum, BSC, Polygon, and Arbitrum**."

Base is not listed. The supported-chains enumeration is exhaustive in context (four chains named,
no "and others" qualifier).

**Corroboration (secondary):** A third-party integration doc
(github.com/finaegis/core-banking-prototype-laravel, docs/RAILGUN_MOBILE_INTEGRATION.md) states
"Base is not supported by RAILGUN." Multiple 2026 explainers list the same four chains.

**What it means for Akmena:** Option (2) "existing rail like RAIL20" is not available on Base
as an official deployment. Integrating Railgun would require either (a) deploying the Railgun
contracts to Base ourselves (unaudited-for-Base, no official relayer/POI infrastructure), or
(b) bridging assets to a supported chain (adds bridge risk, breaks the Base-native design).
Neither is a clean "use the existing rail" story. **Railgun is effectively off the table for a
Base-native privacy layer without significant additional work and risk.**

---

## 2. Privacy Pools (PPOI) — production status — SOURCE-CONFIRMED: MAINNET ONLY

**Primary source:** https://docs.privacypools.com/deployments (official 0xbow deployments page,
read 2026-10-01)

**Quote (full page content):**
> "This section contains the addresses of deployed Privacy Pools contracts across various networks.
> ## Ethereum Mainnet
> | Entrypoint (Proxy) | `0x6818809eefce719e480a7526d76bd3e561526b46` |
> | Entrypoint (Implementation) | `0xdd8aa0560a08e39c0b3a84bba356bc025afbd4c1` |
> | PrivacyPool ETH | `0xf241d57c6debae225c0f2e6ea1529373c9a9c9fb` |
> | WithdrawalVerifier | `0x022891f938ae7fdc8ab9ead0fbf50aba8c897d6d` |
> | RagequitVerifier | `0xa45aca8604a73d80c551faad6355a5c3a5565ec6` |"

No other network is listed. The official deployment is Ethereum mainnet, ETH pool only.

**Corroboration (secondary):** Independent on-chain verification (apoorvlathey/walletchan docs,
2026-07-20) cross-checked these addresses against Ethereum RPC. One unofficial fork of the
0xbow contracts is reported deployed on Base (nu11dotfun/mine-bean) — not official, not audited
by 0xbow, not supported.

**What it means for Akmena:** Privacy Pools is the most credible "existing rail" from a
compliance-design standpoint (association sets, ragequit), but it is **not deployed on Base**
officially. Using it would mean (a) deploying the 0xbow contracts to Base ourselves, (b)
standing up our own ASP (Association Set Provider) infrastructure, and (c) bootstrapping an
anonymity set from zero on Base. The contracts are open source (github.com/0xbow-io), so a
Base deployment is *technically* feasible, but it inherits the "Akmena-owned deployment"
operational burden — it does not buy us an existing anonymity set or existing ASP trust.

---

## 3. Privacy Pools association sets — how exclusion proofs work — SOURCE-CONFIRMED

**Primary sources:**
- https://docs.privacypools.com/layers/asp (official ASP documentation, read 2026-10-01)
- https://privacypools.com/whitepaper.pdf — Buterin, Illum, Nadler, Schar, Soleimani,
  "Blockchain Privacy and Regulatory Compliance: Towards a Practical Equilibrium" (Sep 2023),
  hosted on the official privacypools.com domain

**Quotes (ASP docs):**
> "The Association Set Provider is a crucial compliance layer that controls which deposits can
> be privately withdrawn from Privacy Pools. It maintains a set of approved labels and provides
> the data necessary for cryptographic proofs of label inclusion, bridging privacy with
> regulatory requirements."
> "Withdrawals require valid ASP root" / "Proof must demonstrate label inclusion" /
> "Failed validations trigger ragequit option"

**Quotes (whitepaper, via official site):**
> "The membership proof includes a specific collection of deposits in its association set while
> the exclusion proof's association set consists of anything but a specific collection of
> deposits. **From a technical perspective they are identical, as they both prove against the
> Merkle root of an association set.**"

**Key mechanics (primary-source grounded):**
1. The ASP is an off-chain (or on-chain-constructible) entity that publishes a Merkle root of
   *approved deposit labels*. Only authorized "postmen" can update roots on the Entrypoint.
2. Withdrawal requires a ZK proof of (a) deposit membership in the pool *and* (b) label
   inclusion in the current ASP-approved set.
3. "Exclusion" (proof of innocence / PPOI) is implemented as proving membership in the set of
   *everything except* flagged deposits — technically the same circuit operation as membership.
4. If a label is removed or never approved, the depositor cannot withdraw privately; the
   **ragequit** path lets the *original depositor* publicly exit — a deliberate deanonymizing
   fallback, not a privacy-preserving one.
5. Per the docs' Terms of Use: 0xbow (the ASP operator for the official deployment) conducts
   due diligence on wallet addresses per deposit, can remove addresses at discretion, and
   non-whitelisted users "risk their wallet address being associated with other high-risk
   and/or sanctioned wallet addresses."

**What it means for Akmena:** The association-set model is the compliance answer Elijah asked
for — but it comes with structural implications:
- **Someone must operate the ASP.** For the official deployment that's 0xbow with KYC-style
  due diligence. An Akmena deployment needs an ASP operator decision (self? third party?).
- **Anonymity set = approved set, not global set.** Privacy is bounded by who the ASP admits.
  A small or restrictive set means weak privacy.
- **Ragequit is public.** Users who fail ASP vetting are deanonymized on exit by design.
- **The ASP is a trusted third party** for compliance purposes. This is a fundamentally
  different trust model from a neutral mixer — and must be disclosed as such, not marketed
  as "fully private."

---

## 4. Base / Coinbase on privacy protocols — NOT-ASSESSED (no primary source found)

**Searched:** docs.base.org, base/docs GitHub (terms-of-service.mdx), Coinbase's published
"Neutrality Principles for Base."

**Findings:**
- No official Base documentation stating expectations, prohibitions, or approval processes
  for privacy protocols was found.
- Coinbase's Neutrality Principles (coinbase.com/blog) commit to: Law of Chains, "your keys,
  your crypto," free-market transaction ordering, and equal access to information. They do
  **not** address privacy protocols, mixers, or compliance expectations for builders.
- Base's Terms of Service (base/docs GitHub): "Coinbase does not control what third parties
  may build on Base" — users transact at own risk. No privacy-protocol-specific language
  found in the excerpts reviewed.
- **Base Cobalt upgrade** (announced ~2026-09-30): "transactions submitted through the system
  can remain private until they are included in a block" — this is encrypted-mempool /
  private transaction *submission*, not a privacy pool. Relevant context (Base is moving
  toward confidentiality features) but not a policy statement about third-party privacy
  protocols.

**What it means for Akmena:** There is **no official Base/Coinbase compliance guidance for
privacy protocols** to design against. Elijah's instruction "do not pitch the current pool
to Base" stands — not because Base forbids it, but because there is no documented path and
no official counterpart. Any privacy deployment on Base operates in a policy vacuum: not
prohibited on paper, not endorsed, and subject to the sequencer operator's (Coinbase's)
unilateral transaction-ordering power. **This is a gap to close with direct outreach, not
assumable.**

---

## 5. Tornado Cash sanctions status — SOURCE-CONFIRMED (delisting); later ruling secondary

**Primary source:** U.S. Department of the Treasury press release SB0057, March 21, 2025
https://home.treasury.gov/news/press-releases/sb0057 (read via search-verified official domain)

**Quote:**
> "Based on the Administration's review of the novel legal and policy issues raised by use of
> financial sanctions against financial and commercial activity occurring within evolving
> technology and legal environments, **we have exercised our discretion to remove the economic
> sanctions against Tornado Cash** as reflected in Treasury's Monday filing in
> *Van Loon v. Department of the Treasury*."

Context: OFAC sanctioned Tornado Cash August 2022; Fifth Circuit ruled November 2024 that
immutable smart contracts are not sanctionable "property" under IEEPA; OFAC delisted March 21,
2025. Founder Roman Semenov remains sanctioned (modified designation); criminal cases against
developers continued separately.

**Later development (secondary sources, NOT primary-verified):** CoinTelegraph and others
report that on April 28, 2026, Judge Robert Pitman permanently enjoined OFAC from
reimposing sanctions on Tornado Cash. I did not retrieve the court order itself; treat as
credible-but-secondary.

**What it means for Akmena:** The legal environment for on-chain privacy has materially eased
since 2022 — immutable-contract sanctions were struck down and not reimposed. But:
- The *developers* still faced criminal prosecution (sanctions relief ≠ legal safety for
  operators).
- Treasury "remains deeply concerned" about DPRK laundering and monitors transactions —
  operating a privacy pool still invites scrutiny.
- The lesson for Akmena's design: **immutability was the legal shield** in *Van Loon*.
  An upgradeable, ASP-gated pool (Privacy Pools model) has a *different* legal posture —
  more compliant by design, but also more clearly an operated service with an identifiable
  operator. Choose the model with eyes open about which legal theory protects it.

---

## Decision implications

| Option | Primary-source verdict |
|---|---|
| (1) Akmena-owned pool | Viable technically; ASP operator decision required; anonymity set starts at zero; legal posture depends on upgradeability/operator choices (see §5) |
| (2) Existing rail (RAIL20) | **Not available on Base** — Railgun officially supports only Ethereum, BSC, Polygon, Arbitrum (§1) |
| (2) Existing rail (Privacy Pools) | Deployed on mainnet only; a Base deployment would be Akmena-operated anyway, inheriting option (1)'s burdens without an existing anonymity set (§2) |
| (3) Defer | Remains the lowest-risk option; no primary source *requires* a privacy layer now |

**Open items (still NOT-ASSESSED):**
- Direct Base/Coinbase guidance on privacy protocols (no official doc found — needs outreach).
- Whether 0xbow would support/endorse a Base deployment of Privacy Pools (not asked).
- The April 2026 permanent-injunction ruling (secondary only — retrieve court order if needed
  for legal positioning).
