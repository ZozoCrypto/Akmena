# PrivacyEngine Deployment Runbook — Base Sepolia

## Context

See `PRIVACYENGINE_PROVENANCE_2026-09-30.md` for the full investigation.

- Frontend's configured address (`0x7e5095d10a4B71220938b816398918239981030a`): **no code**
- Previous address (`0x7e5079EDE6eDECf3aC59e1d7E36FBE1038Ac9981`): **pre-fix drainable build**
- This runbook deploys the FIXED PrivacyEngine and wires it up.

The deployment flow has been **simulated on a Base Sepolia fork** and passes
(`test/fork/PrivacyEngineDeploySim.t.sol`). The deployer check, the fixed-build
selector check, and the core registration all work against real chain state.

## Prerequisites

- [ ] `PRIVATE_KEY` env var set to the AkmenaCore deployer key
      (`0x2D4888499D765d387f9CbC48061b28CDe6bC2601`).
      The script enforces this on-chain and reverts otherwise.
- [ ] Base Sepolia ETH for gas (small amount; single contract deployment).
- [ ] `BASESCAN_API_KEY` for `--verify` (optional but recommended).

## Step 1: Deploy

From the repo root (`feature/model-d-operator-custody` branch):

```bash
forge script script/DeployPrivacyEngine.s.sol:DeployPrivacyEngine \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

**Do NOT run without `--broadcast` and mistake the simulation for a deployment.**
Without `--broadcast`, forge only simulates — no contract is created.

Expected output:
```
PrivacyEngine deployed: 0x<NEW_ADDRESS>
Registered akmena.module.privacy -> 0x<NEW_ADDRESS>
```

Save the `<NEW_ADDRESS>`.

## Step 2: Verify on-chain (do not skip)

```bash
# 1. Contract exists
cast code 0x<NEW_ADDRESS> --rpc-url https://sepolia.base.org | head -c 20
# Must return 0x60... (not 0x)

# 2. It's the FIXED build (commitmentAmounts selector must respond)
cast call 0x<NEW_ADDRESS> \
  "commitmentAmounts(bytes32)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  --rpc-url https://sepolia.base.org
# Must return 0x00...00 (32 zero bytes), NOT revert.

# 3. Registered with the core
cast call 0x0C4710331d6e234fE311C1c27252Ad63b7A6ac99 \
  "getModule(bytes32)" \
  0x$(cast keccak "akmena.module.privacy" | cut -c3-) \
  --rpc-url https://sepolia.base.org
# First 32 bytes must equal <NEW_ADDRESS> (lowercased, no 0x prefix).
```

If any check fails: **stop**. Do not update config. Report back.

## Step 3: Record the deployment

Add to `deployments/base-sepolia/deployment.json` under `contracts`:

```json
"PrivacyEngine": {
  "address": "0x<NEW_ADDRESS>",
  "deploymentTx": "0x<TX_HASH>",
  "deploymentBlock": <BLOCK_NUMBER>,
  "version": "2.0.0",
  "note": "Fixed build (commitmentAmounts). Deployed 2026-09-30. Previous frontend address had no code; pre-fix build at 0x7e5079EDE6eDECf3aC59e1d7E36FBE1038Ac9981."
}
```

## Step 4: Update the frontend config

In `frontend/src/config.ts`, replace:

```ts
privacyEngine: '0x7e5095d10a4B71220938b816398918239981030a',
```

with:

```ts
privacyEngine: '0x<NEW_ADDRESS>',
```

Commit both changes together.

## What NOT to do

- Do NOT point config at `0x7e5079EDE6eDECf3aC59e1d7E36FBE1038Ac9981`
  (pre-fix, drainable — proven by selector fingerprint).
- Do NOT reuse `0x7e5095d10a4B71220938b816398918239981030a`
  (no contract deployed there).
- Do NOT skip Step 2. The 2026-09-27 config update wrote an undeployed
  address — verification is what prevents a repeat.
