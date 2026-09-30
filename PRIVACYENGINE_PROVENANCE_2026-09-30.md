# Frontend PrivacyEngine Provenance Investigation — 2026-09-30

## Summary

The frontend's configured `privacyEngine` address is a **dead address** — no
contract is deployed there on Base Sepolia or Base mainnet. The previous
address in git history **does** have a contract, and bytecode fingerprinting
proves it is the **pre-fix, drainable** PrivacyEngine. There is no deployment
record for PrivacyEngine anywhere in the repo.

## Findings

### 1. Current frontend address has no code (SOURCE-CONFIRMED)

`frontend/src/config.ts` (current HEAD):
```
privacyEngine: '0x7e5095d10a4B71220938b816398918239981030a'
```

`eth_getCode` results:
| Chain | Address | Result |
|-------|---------|--------|
| Base Sepolia | `0x7e5095d10a4B71220938b816398918239981030a` | `0x` (no code) |
| Base mainnet | `0x7e5095d10a4B71220938b816398918239981030a` | `0x` (no code) |
| Base Sepolia | `0x0C4710331d6e234fE311C1c27252Ad63b7A6ac99` (core) | 2861 bytes (has code) |
| Base Sepolia | `0xdC3fC3e840b14Ce345638549D0d4617b75cD89b9` (boundary) | 4768 bytes (has code) |

The RPC is working (core and boundary return code). The privacyEngine
address is empty.

### 2. Previous address has the pre-fix drainable contract (CHAIN-VERIFIED)

Commit `eac57776` (2026-08-23) configured:
```
privacyEngine: "0x7e5079EDE6eDECf3aC59e1d7E36FBE1038Ac9981"
```

This address **has** a 1651-byte contract on Base Sepolia.

Bytecode selector fingerprint:
| Selector | In deployed | In fixed build |
|----------|-------------|----------------|
| `depositPrivateEscrow(bytes32)` (`2ace04cc`) | PRESENT | PRESENT |
| `commitments(bytes32)` (`839df945`) | PRESENT | PRESENT |
| `commitmentAmounts(bytes32)` (`bca44922`) — added by fix | **ABSENT** | PRESENT |

The deployed contract lacks the `commitmentAmounts` mapping introduced by
the 1-wei drain fix. It is the **pre-fix, drainable** PrivacyEngine.

The pre-fix source (`8f25290d:src/privacy/PrivacyEngine.sol`) confirms:
```solidity
function depositPrivateEscrow(bytes32 commitment) external payable {
    if (msg.value == 0) revert InvalidCommitment();
    if (commitments[commitment]) revert CommitmentAlreadyExists();
    commitments[commitment] = true;  // records commitment, NOT the amount
    emit CommitmentDeposited(commitment, msg.value);
}
```

### 3. No deployment record exists (SOURCE-CONFIRMED)

- `deployments/base-sepolia/deployment.json` has **no PrivacyEngine entry**.
- It records only 4 contracts (Core, Escrow, Boundary, Authorization).
- `script/DeployAkmena.s.sol` DOES deploy PrivacyEngine (line 134), so the
  deployment script covers it — but no record was kept.
- `git log` shows `frontend/src/config.ts` was touched only twice:
  `eac57776` (restore) and `8deead98` (address update).

### 4. Frontend does not currently call it (SOURCE-CONFIRMED)

- Only `frontend/src/config.ts` references `privacyEngine`. No `.ts`/`.tsx`
  file imports or calls it.
- `frontend/src/abi/PrivacyEngine.json` exists — the ABI is staged for future use.

## Risk assessment

1. **No live user funds at risk right now** — the frontend never calls the
   dead address.
2. **Landmine**: anyone activating the privacy UI via `config.ts` would send
   deposits to an address with no code. A payable call to an empty address
   succeeds at the EVM level and the ETH is irrecoverable.
3. **Old builds are dangerous**: any cached/deployed old frontend (or anyone
   using the `eac57776` addresses) points at the drainable PrivacyEngine.
4. **R13 is blocked**: frontend adversarial testing cannot proceed until the
   privacyEngine address resolves to the fixed contract.

## Recommended actions (require Elijah's approval)

1. Deploy the fixed PrivacyEngine to Base Sepolia (no live-chain action taken).
2. Record the deployment in `deployment.json` (deployer, tx, block, address).
3. Update `frontend/src/config.ts` with the verified address.
4. Verify on-chain bytecode matches the fixed build before updating config.
