# Akmena Deployment Runbook (DRAFT)
**Status:** DRAFT — Not approved. Do not execute without Elijah's explicit approval.
**Date:** 2026-10-01

---

## 1. Preflight Checks

### 1.1 Source Verification
- [ ] Confirm git branch: `feature/model-d-operator-custody` (or release branch as designated)
- [ ] Confirm git commit hash matches the approved revision: `________________`
- [ ] Verify `git status` is clean (no uncommitted changes to `src/`)
- [ ] Verify `git diff HEAD -- src/` returns empty
- [ ] Record Foundry version: `forge --version`

### 1.2 Configuration Verification
- [ ] EIP-712 version in `AkmenaExecutionAuthorization.sol` constructor: must be `"2"`
- [ ] Deployment draft (`deployment.json.DRAFT`) reviewed and approved by Elijah
- [ ] Chain ID correct for target network (Base Sepolia: 84532, Base mainnet: 845)
- [ ] Deployer address has sufficient ETH for gas

### 1.3 Governance Pre-Deployment
- [ ] Safe multisig deployed with 3-of-5 threshold (or as approved)
- [ ] All 5 owner addresses verified
- [ ] TimelockController deployed with 24h delay
- [ ] Pause guardian key generated and secured (hardware wallet)

### 1.4 Security
- [ ] Slither triage complete with zero unresolved High/Medium
- [ ] R14 full suite passes at the deployment revision
- [ ] No outstanding critical findings in the readiness checklist

---

## 2. Deployment

### 2.1 Deploy Core Contracts
Deploy in order (dependencies):
1. `AkmenaCore` (constructor: no args — verify)
2. `AkmenaPolicyBoundary` (constructor: `address(core)`)
   - Note: deploys `AkmenaExecutionAuthorization` internally
3. `EscrowEngine` (constructor args: verify against source)

**Record for each:**
- Contract address
- Deployment transaction hash
- Deployment block number
- Git commit hash (source revision)

### 2.2 Post-Deployment Verification
- [ ] Verify contract code on block explorer (BaseScan)
- [ ] Recompile from source and compare bytecode:
  ```bash
  forge build --force
  # Compare deployed bytecode vs compiled artifact
  cast code <address> --rpc-url <RPC> > deployed.hex
  # Compare against out/AkmenaCore.sol/AkmenaCore.json
  ```
- [ ] Verify EIP-712 domain separator:
  - Name: `AkmenaExecutionAuthorization`
  - Version: `2`
  - Chain ID: matches deployment chain
  - Verifying contract: matches deployed auth address

### 2.3 Initial Configuration
- [ ] `core.setPauseGuardian(<guardian_address>)` — deployer only
- [ ] Verify `core.pauseGuardian()` returns the correct address
- [ ] Do NOT set any economic adapters yet (requires G-4 admission)
- [ ] Do NOT transfer admin roles yet (G-7 migration is separate)

---

## 3. Governance Migration (G-7)

**Prerequisite:** All contracts deployed and verified. Multisig and timelock deployed.

### 3.1 Transfer Allowlist Admin (Slow Path)
1. Deployer calls `boundary.transferAllowlistAdmin(<timelock_address>)`
2. Verify `boundary.allowlistAdmin()` == timelock address
3. Verify deployer can NO LONGER call `setEconomicAdapter`

### 3.2 Transfer Emergency Admin (Fast Path)
1. Deployer calls `boundary.transferEmergencyAdmin(<safe_address>)`
2. Verify `boundary.emergencyAdmin()` == Safe address
3. Verify deployer can NO LONGER call `emergencyRemoveAdapter`

### 3.3 Verify Deployer Disempowerment
- [ ] Attempt `setEconomicAdapter` from deployer → must revert
- [ ] Attempt `emergencyRemoveAdapter` from deployer → must revert
- [ ] Confirm timelock can queue `setEconomicAdapter` (via Safe proposal)
- [ ] Confirm Safe can directly call `emergencyRemoveAdapter`

### 3.4 Emergency Drill
**Purpose:** Validate the full governance chain works under pressure.

1. **Queue test:** Safe proposes a test adapter addition via timelock. Verify it queues with 24h delay.
2. **Cancel test:** Safe cancels the queued proposal during the delay. Verify cancellation works.
3. **Pause test:** Guardian calls `core.setPaused(true)`. Verify all settlements halt.
4. **Remove test:** Safe calls `emergencyRemoveAdapter`. Verify immediate removal.
5. **Unpause test:** Deployer calls `core.setPaused(false)` (or via timelock if migrated). Verify resumption.
6. **Document:** Record all transaction hashes, block numbers, and timing.

---

## 4. Rollback Considerations

### 4.1 If Deployment Fails
- Contracts are not upgradeable. A failed deployment requires redeployment.
- Record the failure reason. Do not retry blindly.
- If a contract was deployed but configuration failed, assess whether redeployment is cleaner than repair.

### 4.2 If Governance Migration Fails
- If `transferAllowlistAdmin` succeeds but `transferEmergencyAdmin` fails: the timelock controls adds, deployer still controls emergency removal. This is a degraded but functional state. Complete the emergency transfer before proceeding.
- If both transfers fail: deployer retains full control. Do not proceed to mainnet. Diagnose and retry.

### 4.3 If Emergency Drill Fails
- Do not proceed to mainnet. The governance chain is the last line of defense.
- Document the failure mode. Fix the configuration. Re-run the drill.

### 4.4 Post-Deployment Issues
- **Critical bug in production contracts:** No upgrade path. Options: (a) pause via guardian, (b) migrate to new deployment, (c) social consensus for operator allowance revocation.
- **Compromised deployer key (pre-migration):** Immediately execute G-7 migration from a secure key. If deployer key is lost before migration, the contracts are ungovernable — redeploy.
- **Compromised guardian key:** Deployer calls `setPauseGuardian(new_address)`. The old guardian can only pause (DoS), not steal funds.

---

## 5. Post-Deployment Checklist

- [ ] All contract addresses recorded in `deployment.json` (final, not draft)
- [ ] Bytecode verified against source
- [ ] EIP-712 v2 domain confirmed
- [ ] Governance roles transferred and verified
- [ ] Emergency drill completed successfully
- [ ] Monitoring configured for `EconomicAdapterUpdated` events
- [ ] Incident response runbook accessible to all key holders
- [ ] Deployment report signed by Elijah

---

## Approvals

| Step | Approver | Signature | Date |
|------|----------|-----------|------|
| Preflight complete | Elijah | | |
| Deployment executed | (operator) | | |
| Bytecode verified | Muse | | |
| Governance migrated | Elijah | | |
| Emergency drill passed | Elijah | | |
| Ready for mainnet | Elijah | | |
