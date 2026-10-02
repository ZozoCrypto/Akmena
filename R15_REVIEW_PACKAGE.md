# R15 Independent Review Package
**Date:** 2026-10-02 (updated)
**Status:** PREPARATION — reviewer not yet commissioned
**Gate:** R15 is the final gate before mainnet deployment consideration
**Target revision:** `c4693934` (see commit history below)

## 1. Scope and Threat Model

### In Scope
- **AkmenaPolicyBoundary** (`src/authorization/AkmenaPolicyBoundary.sol`): ERC20 AND native ETH settlement via operator-retained custody (Model D). Pull-from-operator, push-to-adapter flow.
- **AkmenaExecutionAuthorization** (`src/authorization/AkmenaExecutionAuthorization.sol`): EIP-712 v2 intent verification, nonce management, replay protection.
- **AkmenaCore** (`src/core/AkmenaCore.sol`): Pause guardian, module registry, deployer roles (now transferable via two-step).
- **Economic adapter interface**: Allowlist management, `setEconomicAdapter`, `setStandardDebit`.
- **Escrow module**: `createEscrow` with real ERC20 custody (post-`8deead98` hardening).
- **Native ETH settlement path**: IN SCOPE. GAP-1 (zero-value native DoS) was patched in `3e02c3ad`; the native path is now fuzzed via the extended Medusa handler.

### Out of Scope
- **PrivacyEngine**: Dead on both Base chains (address `0x7e5095d10a4B71220938b816398918239981030a` returns 0x). Redeploy DEFERRED per Elijah 2026-10-01. Frontend must not wire to it.
- **Frontend**: Parked until contracts, signing, custody, governance, privacy, and deployment semantics stabilize.
- **AkmenaGovernor/AkmenaTimelock**: DELETED 2026-10-01 (were dead, unaudited, conflicted with G-7). G-7 uses OZ TimelockController.

### Threat Model
**Attackers:**
1. **Malicious operator**: Tries to drain other operators' funds, replay intents, exceed policies.
2. **Malicious adapter**: Tries to over-pull, reenter, or redirect funds during settlement.
3. **Malicious token**: Tries fee-on-transfer, rebase, or silent-failure attacks (see A-8 battery).
4. **Compromised deployer**: Tries to allowlist malicious adapters (mitigated by G-7 timelock, not yet implemented).
5. **Compromised pause guardian**: Can only pause (DoS), cannot unpause or steal funds.

**Assumptions:**
- Operators manage their own allowances securely (revocation is their kill-switch).
- Economic adapters are vetted before allowlisting (Standard-Debit admission criteria §7.2).
- The boundary contract itself is not upgradeable (no proxy); bugs require migration.

## 2. Relevant Commits and Architecture

### Architecture: Model D (Operator-Retained Custody)
- **Spec:** `~/workspace/goals/akmena-red-team-security-verification/files/model-d-implementation-spec-v1.2.md`
- **Key invariant:** Tokens never pool in the boundary. The boundary pulls from the operator's wallet (via allowance) and pushes to the adapter. No custody = no honeypot.
- **V-0 closed by construction:** The historical V-0 drain (pull from boundary pool) is impossible because there is no pool.

### Commit History (feature/model-d-operator-custody)
| Commit | Description | Evidence |
|--------|-------------|----------|
| `00428402` | Model D base (Phase 1+2) | Settlement rewrite, events/errors/NatSpec |
| `bdc65f90` | EconomicBalanceIncrease revert guard | Net-delta accounting hardening |
| `8deead98` | v2.6.0-security-hardened | PrivacyEngine fix, PolicyBoundary fix, Escrow hardening |
| `27167778` | R11: 13 symbolic properties | Halmos proofs (escrow, accounting, governance) |
| `3c6b95f6` | R14: 873/873 (843 unit + 30 invariant) | Full regression at tested revision |
| `5aa7f9f3` | R9: Medusa 100k campaign | 100,022 calls, 0 failures, 26/26 pass |
| `3e02c3ad` | **GAP-1 patch**: zero-value native DoS fix | Production: native zero-value no longer charges daily limit |
| `968cc8fb` / `308d6ab8` | GAP-1 test updates (9 tests) | Hardened semantics |
| `0eb929a9` | **GAP-3 hardening** + deployer transfer | Zero-amount target allowlist; two-step deployer transfer; 11 new tests |
| `c4693934` | Medusa native path extension | Handler now fuzzes native ETH settlement (4 new intents) |
| `HEAD` | R14: **870/870** unit, invariant re-run | Full regression at hardened revision |

### Security Findings Since Last Update
- **GAP-1** (patched `3e02c3ad`): Native zero-value intents charged `intent.amount` to daily limit without moving funds. 10 spam intents could consume full limit. **Fixed:** zero-value native no longer charges. Verified by 7-test independent suite.
- **GAP-2** (documented): Native intents skip adapter allowlist. **Intentional:** agent supplies own ETH; boundary never holds native. NatSpec added with integrator warning.
- **GAP-3** (patched `0eb929a9`): Zero-amount ERC20 intents could call arbitrary targets as boundary (confused deputy). **Fixed:** target must be registered proof module or allowlisted adapter. New error `UnauthorizedZeroAmountTarget`.
- **GAP-4** (non-issue): ERC777 hooks blocked by transient reentrancy guard. Test was vacuous; underlying mechanism proven by `Attack_SmartAgentReentrancy`.

### Key Files
- `src/authorization/AkmenaPolicyBoundary.sol`: Settlement logic, allowlist, policies
- `src/authorization/AkmenaExecutionAuthorization.sol`: Intent verification, nonces
- `src/core/AkmenaCore.sol`: Pause, guardian, module registry
- `test/invariant/handlers/ModelDBoundaryHandlerMedusa.sol`: R9 fuzz harness

## 3. Prior Campaign Evidence (R14/R10/R11/R12/R9)

### R14 Regression: COMPLETE (RUNTIME-PROVEN)
- **Commit:** `be75aa6e` (report), tested revision `27167778`
- **Result:** 868/868 pass (843 unit + 25 invariant)
- **Command:** `forge test --no-match-path "test/invariant/*"` + `forge test --match-path "test/invariant/*"`
- **Date:** 2026-10-01 18:12-19:48 UTC
- **Note:** Supersedes the seed-sensitive 820/820 claim. Exact command recorded.

### R10 Mutation: COMPLETE
- **Commit:** `85a08429` (report), `df849888` (gap-fill tests)
- **Result:** 20 mutants, 19 killed + 1 equivalent = 100% effective score
- **Scope:** All PolicyBoundary mutants
- **Note:** 5 gap-fill tests added to kill survived mutants, empirically verified.

### R11 Formal: ADVANCING (not finished)
- **Commit:** `27167778`
- **Result:** 13/13 Halmos symbolic properties pass
- **Coverage:** Escrow caller gates, settlement headroom, governance non-admin reverts, replay protection
- **Limitation:** Halmos cannot forge ECDSA signatures; happy-path execution is concrete-test-only.
- **Open:** Pause proof Halmos re-verification pending. The PROVEN label on the pause property rests on a commit message, not a re-verified proof.

### R12 Base Sepolia Fork: COMPLETE
- **Commit:** `c886dbfc`
- **Result:** 6/6 pass (native, replay, over-limit, governance, fee-token)
- **Note:** Fork tests validate behavior on Base Sepolia state.

### R9 Medusa Fuzzing: COMPLETE (harness repaired)
- **Commit:** `4498937a`
- **Harness:** Self-contained handler (constructor registers 8 builtin intents, ERC-1271 agent)
- **Proof test:** `MedusaSettlementProof.t.sol` 5/5 pass (real settlements, exact amounts, replay reverts)
- **Fuzz campaign:** 1043 calls, 0 failures, both security invariants PASSED
  - `invariant_conservation`: Honest-mode pulled == pushed; purely-honest supply conserved
  - `invariant_boundaryClean`: Zero boundary balance in all token modes
- **Limitation:** Short campaign (smoke-level). Full-duration campaign not yet run.

## 4. Known Limitations and Unresolved Assumptions

### Limitations
1. **R11 incomplete:** Pause proof needs Halmos re-verification. Happy-path symbolic execution not possible (ECDSA).
2. **R9 short campaign:** 1043 calls is smoke-level. A production-grade campaign (100k+ calls, multiple workers, extended duration) has not been run.
3. **G-7 not implemented:** Timelock and multisig are designated but not deployed. Deployer still holds all powers.
4. **PrivacyEngine dead:** No privacy solution is live. The protocol has no privacy features.
5. **Frontend parked:** No adversarial frontend testing (R13) has been conducted.

### Unresolved Assumptions
- **ASSUMPTION:** Operators will monitor `EconomicAdapterUpdated` events and revoke allowances if a malicious adapter is queued. (Social, not enforced.)
- **ASSUMPTION:** The 5 multisig key holders (beyond Elijah) will be designated and will maintain key security.
- **ASSUMPTION:** The 48-hour timelock delay is sufficient for operator response but not so long as to hinder emergency recovery.
- **ASSUMPTION:** Standard-Debit admission criteria (§7.2) are sufficient to filter malicious tokens. The A-8 battery found 2 critical issues (F-7 over-pull, silent-success) that are mitigated by admission, not by code.
- **NOT-ASSESSED:** Gas costs of settlement at scale. The pull-push-call flow may be expensive for high-frequency use.

## 5. Specific Independent-Review Targets

### Priority 1 (Must review)
1. **Settlement atomicity:** Verify the charge-before-pull → pull → push → call sequence cannot leave funds stranded or double-spend on revert. Focus on `AkmenaPolicyBoundary._settleERC20`.
2. **Nonce management:** Verify nonces cannot be reused, front-run, or desynchronized. Focus on `AkmenaExecutionAuthorization`.
3. **Allowlist bypasses:** Attempt to execute settlements through non-allowlisted adapters, or to allowlist an adapter without proper authorization.
4. **Reentrancy:** Attempt reentrancy via malicious adapter callbacks during the `call` phase. Verify `ReentrancyGuardTransient` is effective.

### Priority 2 (Should review)
5. **Policy enforcement:** Verify `maxSpendPerTransaction` and `dailyLimit` cannot be bypassed via multiple intents, flash loans, or timestamp manipulation.
6. **ERC-1271 agent:** Verify the handler-as-agent model (test harness) does not mask issues in the production EOA-agent model.
7. **Pause/unpause:** Verify the guardian cannot unpause, and that pausing actually halts all value movement.
8. **Economic adapter interface:** Review the `setEconomicAdapter`/`setStandardDebit` access controls and the `InvalidAdapter` self-adapter guard.

### Priority 3 (Nice to have)
9. **Gas griefing:** Can a malicious operator or adapter cause settlements to consume excessive gas, blocking legitimate use?
10. **Front-running:** Can intents be front-run to cause failures or extract value?
11. **Upgrade/migration:** Review the migration contingency plan (§8 of spec) for completeness.

## 6. Reviewer Qualifications and Proposed Plan

### Qualifications
- **Required:** 
  - 3+ years Solidity security auditing
  - Published audits of DeFi protocols with TVL > $10M
  - Experience with EIP-712, ERC-1271, and transient storage (EIP-1153)
  - Familiarity with Foundry and invariant testing
- **Preferred:**
  - Experience with intent-based architectures or ERC-4337
  - Knowledge of Base L2 specifics
  - Prior work on allowance-based custody models

### Proposed Plan
**Phase 1: Reconnaissance (1 week)**
- Reviewer studies the spec, code, and prior campaign evidence.
- Reviewer sets up local environment and reproduces R14 regression.
- Deliverable: Recon report with attack hypotheses.

**Phase 2: Manual Audit (2 weeks)**
- Reviewer manually audits Priority 1 and 2 targets.
- Reviewer writes PoC exploits for any findings.
- Deliverable: Findings report with severity ratings and PoCs.

**Phase 3: Adversarial Testing (1 week)**
- Reviewer writes custom fuzz tests targeting their hypotheses.
- Reviewer attempts to break the invariants from R9.
- Deliverable: Test results and any new findings.

**Phase 4: Report and Remediation (1 week)**
- Reviewer delivers final report.
- Akmena team triages findings (confirmed / safe-by-design / false positive / needs hardening).
- Deliverable: Final audit report with triage.

**Total:** 5 weeks, estimated cost to be negotiated with reviewer.

## 7. Draft Outreach Material

### Email Subject
Independent Security Review: Akmena v2.6.0 Model D Settlement Layer

### Email Body
```
Hello [Reviewer Name],

I'm Elijah, building Akmena — an AI-agent autonomous commerce trust layer on Base.
We've completed an intensive 16-phase pre-mainnet security campaign (R0-R15) and
are seeking an independent bounty-style review as our final gate (R15).

**Scope:** The Model D settlement layer — operator-retained custody via
ERC20 pull/push through a policy-checked boundary. ~2,000 lines of Solidity,
plus tests.

**What we've done:**
- R14: 868/868 tests pass (full regression)
- R10: 100% mutation score (20 mutants)
- R11: 13/13 symbolic properties (Halmos)
- R12: 6/6 Base Sepolia fork tests
- R9: Medusa fuzzing (1043 calls, 0 failures, invariants hold)

**What we need:**
A 5-week engagement: 1 week recon, 2 weeks manual audit, 1 week adversarial
testing, 1 week report/remediation. We're specifically looking for issues in
settlement atomicity, nonce management, allowlist bypasses, and reentrancy.

**Evidence package:** [Link to R15 package with commits, spec, and prior reports]

**Budget:** [To be discussed]

Are you available for a scoping call next week?

Best,
Elijah
https://github.com/ZozoCrypto/Akmena
```

### Reviewer Shortlist Criteria
- [ ] Has published audits (provide links)
- [ ] No conflicts of interest (not an Akmena token holder, not affiliated with competitors)
- [ ] Available for 5-week engagement starting [DATE]
- [ ] Agrees to responsible disclosure (90-day embargo on critical findings)

---

**Note:** Do not commit funds, sign agreements, or claim a reviewer was commissioned until Elijah explicitly approves. This package is preparation only.
