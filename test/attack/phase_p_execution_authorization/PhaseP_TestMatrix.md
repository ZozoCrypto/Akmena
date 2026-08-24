# Phase P Execution Authorization Test Matrix

| ID | Attack | Expected |
|---|---|---|
| P-01 | Operator substitution | REVERT |
| P-02 | Agent substitution | REVERT |
| P-03 | Target substitution | REVERT |
| P-04 | Selector substitution | REVERT |
| P-05 | Calldata substitution | REVERT |
| P-06 | Amount substitution | REVERT |
| P-07 | Native value substitution | REVERT |
| P-08 | Proof module substitution | REVERT |
| P-09 | Proof ID substitution | REVERT |
| P-10 | Replay | REVERT |
| P-11 | Expired authorization | REVERT |
| P-12 | Before-valid authorization | REVERT |
| P-13 | Policy target violation | REVERT |
| P-14 | Policy selector violation | REVERT |
| P-15 | Daily limit violation | REVERT |
| P-16 | Reentrancy | REVERT |
| P-17 | Disabled proof module | REVERT |
| P-18 | Exact authorized execution | PASS |
