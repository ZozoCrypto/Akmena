# ABI Generation Record — Frozen Candidate d0848055

**Date:** 2026-10-03
**Source revision:** `d0848055e0545f24c9bb3b32df4c96fe57447e10`
**Status:** VERIFIED ✅

---

## Generation Command

```bash
cd /home/hatch/workspace/akmena-v260
export PATH="$HOME/.foundry/bin:$PATH"
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
forge build
```

**Toolchain:**
- Forge: nightly (FOUNDRY_DISABLE_NIGHTLY_WARNING=1)
- Solc: 0.8.28
- Source: `d0848055` (frozen candidate)

---

## Source Verification

- **HEAD before generation:** `3567427660d892551846178ea6f40d85d98cca93`
- **Source diff d0848055..35674276:** Empty (no source changes)
- **HEAD after generation:** `3567427660d892551846178ea6f40d85d98cca93` (unchanged)
- **Contract sources:** Unmodified by ABI generation ✅

---

## ABIs Generated

| Contract | File | Functions | Notes |
|----------|------|-----------|-------|
| AkmenaCore | `AkmenaCore.json` | Includes `proposeDeployer`, `acceptDeployer`, `cancelDeployerTransfer`, `pendingDeployer` | Deployer transfer (GAP-3 era) |
| AkmenaPolicyBoundary | `AkmenaPolicyBoundary.json` | Includes `setAgentPolicy`, `setAgentAssetPolicy`, `UnauthorizedZeroAmountTarget` error | GAP-1, GAP-3, isEnabled |
| AkmenaExecutionAuthorization | `AkmenaExecutionAuthorization.json` | EIP-712 v2 | — |
| EscrowEngine | `EscrowEngine.json` | Escrow functions | — |
| AkmenaToken | `AkmenaToken.json` | ERC-20 + Permit | For allowance UI |

**Location:** `abis/frozen-d0848055/`

---

## Verification

- [x] ABIs extracted from `forge build` output at frozen revision
- [x] `proposeDeployer` present in AkmenaCore ABI
- [x] `UnauthorizedZeroAmountTarget` present in Boundary ABI
- [x] `setAgentPolicy`/`setAgentAssetPolicy` present in Boundary ABI
- [x] Contract sources unchanged by generation
- [x] HEAD unchanged by generation

---

## Traceability

```
d0848055 (frozen contract candidate)
  → forge build (solc 0.8.28)
    → out/*.sol/*.json (build artifacts)
      → abis/frozen-d0848055/*.json (extracted ABIs)
        → frontend/src/abi/* (next: copy to frontend)
```

---

## Next Steps

1. Copy ABIs to `frontend/src/abi/` (replacing stale versions)
2. Update `frontend/src/config.ts` with frozen addresses
3. Frontend implementation may begin
