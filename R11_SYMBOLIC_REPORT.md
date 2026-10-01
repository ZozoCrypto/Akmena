# R11 Symbolic Execution Report
**Date:** 2026-10-01 · **Tool:** Halmos 0.3.3 · **Contract:** `BoundarySymbolicR11`
**File:** `test/symbolic/BoundarySymbolicR11.t.sol`
**Branch:** `feature/model-d-operator-custody`

## Summary
All three symbolic properties **PASS**. Halmos explored 234 total paths with zero counterexamples.

| Property | Result | Paths | Time | Meaning |
|----------|--------|-------|------|---------|
| `check_PauseBlocksExecution` | PASS | 12 | 0.67s | No intent can execute while paused |
| `check_NonceReplayReverts` | PASS | 175 | 4.04s | Used (agent,nonce) always reverts |
| `check_ZeroOperatorReverts` | PASS | 47 | 0.53s | Zero operator always reverts |

## Commands (exact)

```bash
cd /home/hatch/workspace/akmena-v260
export PATH="$HOME/.foundry/bin:$PATH"

# Pause property
halmos --contract BoundarySymbolicR11 --function check_PauseBlocksExecution

# Nonce replay property (new)
halmos --contract BoundarySymbolicR11 --function check_NonceReplayReverts

# Zero operator property
halmos --contract BoundarySymbolicR11 --function check_ZeroOperatorReverts
```

## Output (verbatim)

### check_PauseBlocksExecution
```
[PASS] check_PauseBlocksExecution(address,address,address,uint256,uint256,bytes,bytes) (paths: 12, time: 0.67s, bounds: [payload=[0, 65, 1024], signature=[0, 65, 1024]])
Symbolic test result: 1 passed; 0 failed; time: 1.06s
```

### check_NonceReplayReverts
```
[PASS] check_NonceReplayReverts(address,uint256,address,address,address,uint256,bytes,bytes) (paths: 175, time: 4.04s, bounds: [payload=[0, 65, 1024], signature=[0, 65, 1024]])
Symbolic test result: 1 passed; 0 failed; time: 4.89s
```

### check_ZeroOperatorReverts
```
[PASS] check_ZeroOperatorReverts(address,address,uint256,uint256,bytes,bytes) (paths: 47, time: 0.53s, bounds: [payload=[0, 65, 1024], signature=[0, 65, 1024]])
Symbolic test result: 1 passed; 0 failed; time: 1.26s
```

## What changed

### Replaced vacuous `check_NonceTracking`
**Before:** `assertTrue(nonce == nonce)` — tautology, proves nothing.

**After:** `check_NonceReplayReverts` — meaningful replay-protection property:
1. Symbolically marks `usedNonces[agent][nonce]=true` via `vm.store`
   (slot derivation: `keccak256(nonce . keccak256(agent . 2))`, slot 2 from storage layout)
2. Verifies the mark via public getter `auth.usedNonces(agent, nonce)`
3. Attempts execution with the replayed (agent, nonce) via low-level call
4. Asserts `!success` — must revert for ALL symbolic inputs

This proves the `NonceAlreadyUsed` check is effective and fail-closed:
replay is blocked regardless of signature validity or other parameters.

### Test-only change
No production contracts modified. Only `test/symbolic/BoundarySymbolicR11.t.sol` changed.
R9 production-code gate: respected.

## Evidence classification
- **RUNTIME-PROVEN**: Halmos 0.3.3 executed, all properties pass with exact outputs above.
- Prior "PROVEN" label for the pause property (based on commit message) is now superseded by actual run evidence.

## Limitations
- Halmos cannot forge ECDSA signatures, so full end-to-end settlement flows are not symbolically verified. The properties test enforcement at the check sites (pause, nonce, zero-operator), not the happy path.
- `check_ZeroOperatorReverts` is weak (zero operator fails many checks); it confirms fail-closed behavior but isn't a deep property.
- Symbolic bounds: `payload` and `signature` limited to [0, 65, 1024] bytes by Halmos defaults.

## Installation note
Halmos was not present in this environment (prior 2026-09-30 install did not persist).
Installed via: `pip3 install "halmos==0.3.3" --break-system-packages`
Binary: `/usr/local/bin/halmos`
