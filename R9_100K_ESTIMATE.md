# R9 100k+ Campaign: Scope and Resource Estimate
**Date:** 2026-10-01
**Status:** ESTIMATE ONLY — Not approved. Elijah deferred this as a separate decision.

---

## Current Coverage

| Campaign | Calls | Branches | Corpus | Failures | Duration |
|----------|-------|----------|--------|----------|----------|
| Smoke | 1,043 | 920 | 25 | 0 | ~2 min |
| Extended | 11,114 | 928 | 33 | 0 | ~21 sec* |

*The extended campaign hit the `testLimit` (10,000) quickly due to high throughput (~550 calls/sec with 4 workers). Wall-clock time was short but call volume was substantial.

**Properties exercised:** `invariant_conservation`, `invariant_boundaryClean` (both pass). 26 assertion/property tests total.

## Coverage Gaps in Current Campaign

1. **Call volume:** 11k calls is meaningful but not exhaustive. Stateful fuzzers benefit from longer runs that explore deeper call sequences.
2. **Sequence depth:** `callSequenceLength: 100`. Deeper sequences (200+) might reveal multi-step attack chains.
3. **Worker count:** 4 workers used. More workers = more parallel exploration.
4. **Duration:** Both campaigns were time-bounded by `testLimit`, not wall-clock. A true soak test would run for hours.
5. **Malicious token modes:** The handler supports modes 0-7 (honest + 7 malicious). Current campaigns fuzz `setTokenMode`, but dedicated per-mode campaigns would provide stronger guarantees.

## Proposed 100k+ Campaign

### Configuration
```json
{
  "fuzzing": {
    "testLimit": 100000,
    "timeout": 3600,
    "workers": 8,
    "callSequenceLength": 200
  }
}
```

### Resource Estimate

| Resource | Estimate | Notes |
|----------|----------|-------|
| Wall-clock time | 3-5 minutes | At ~550 calls/sec with 8 workers, 100k calls ≈ 3 min. Plus ~2 min compilation. |
| CPU | 8 cores | Medusa workers are CPU-bound during fuzzing |
| Memory | ~4 GB | EVM state + corpus |
| Disk | < 500 MB | Corpus + logs |

**Note:** The bottleneck is not wall-clock time but call throughput. Medusa is fast. A 100k campaign is feasible in under 10 minutes on this machine.

### Extended Soak Test (Optional)

For maximum confidence, a 1-hour soak with no `testLimit`:

| Resource | Estimate |
|----------|----------|
| Wall-clock time | 60 minutes |
| Estimated calls | ~2M (at 550/sec) |
| CPU | 8 cores sustained |
| Memory | ~4 GB |

This would provide the strongest R9 evidence but is likely overkill given the 11k campaign already passes with zero failures.

## Recommendation

**Run the 100k campaign** (3-5 min, minimal resource cost). It 10x's the current coverage for negligible time investment.

**Skip the 1-hour soak** unless the 100k campaign surfaces new behavior. The current evidence (11k calls, 0 failures, both invariants hold) is already strong for a harness of this complexity.

## Decision Required

Elijah: Approve the 100k campaign? It can run immediately upon approval.
