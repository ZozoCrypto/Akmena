# Phase P Legacy Security Reproducers

These tests are historical security reproducers from an earlier
authorization architecture.

They are intentionally excluded from the active Phase P execution
authorization suite because the production authorization model has
since evolved.

## Files

- `Attack_AuthorizationLifecycle.t.sol`
  - Historical authorization state-machine model.
  - Uses EXECUTED / CANCELLED / EXPIRED state tracking.

- `Attack_NonceGriefing.t.sol`
  - Historical nonce/cancellation reproducer.
  - Uses an older EIP-712 authorization model.

- `Attack_StateEIP712Reproducer.t.sol`
  - Historical EIP-712 state reproducer.
  - Isolated from the current production authorization contract.

## Policy

These files are preserved for audit history and regression archaeology.

They are not part of the active production security test suite.

If future protocol changes make one of these scenarios relevant again,
promote the scenario into a new production-bound attack test rather
than re-enabling the historical harness unchanged.
