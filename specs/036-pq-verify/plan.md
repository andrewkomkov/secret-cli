# Implementation Plan: `touchid pq` checks the values before the write

**Spec**: `specs/036-pq-verify/spec.md`

## Technical Context

- `helper/store/main.swift`, `upgradePQ`: a loop of `unseal` with the context `c` after `seal`,
  before `writeFile`. An error is `VaultError.damaged`; `withStoreLock` exits without a write.
- Cost: a second read of each value in the Secure Enclave. Touch ID is not asked: the context is
  already confirmed.

## Constitution Check

- **I**: the values stay in the helper memory.
- **II**: one Touch ID question, as in 033.
- **IV**: the 033 tests pass through the new check.
- **V**: the behaviour on success does not change.

## Complexity Tracking

No deviations.
