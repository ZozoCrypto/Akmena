
## Full Regression — 2026-09-30 (post-Chaos fix)

**Commit:** 0f1e58f1 (includes R12 fork test)

### Results

| Suite | Command | Result |
|-------|---------|--------|
| Non-invariant | `forge test --no-match-path "test/*nvariant*"` | **794/794 PASS** |
| V3 Honest | `forge test --match-contract "ModelDBoundaryInvariantV3"` | **PASS** (820s) |
| V3 Malicious | (same run) | **PASS** |
| R12 Fork | `forge test --match-contract "ModelDBaseSepoliaForkTest"` | **4/4 PASS** |

**Total: 800/800 PASS**

### Notes

- The Chaos escrow failures (testFuzz_CannotRefundUnlessSeller,
  testFuzz_CannotReleaseUnlessBuyer) are fixed and verified in the
  full regression run.
- V3 invariant campaigns: 1000 runs / 500,000 calls each, both green.
- R12 fork tests run against Base Sepolia block 47517890 with real USDC.
- No production contract changes in this regression cycle.
