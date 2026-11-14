# Feature Specification: `touchid pq` checks the values before the write

**Feature Branch**: `036-pq-verify`

**Created**: 2026-11-14

**Status**: Draft 2026-11-14

**Input**: Owner: "make sure about the store" before the migration of the real store (033 T010).

## Goal

Nobody checked on hardware the decryption with the real ML-KEM key in the Secure Enclave after
Touch ID. The check of 2026-11-11 covered only the refusal without Touch ID. If the key seals but
does not open, `touchid pq` leaves values that nobody can read.

After the fix, `touchid pq` opens each new value with the same context before the file write. If
at least one value did not open or did not match, the command fails with an error and does not
change the file.

## Requirements

- **FR-001**: in `upgradePQ` after `seal` — `unseal` of each new value, `check` and `wm`.
  Comparison with the original value.
- **FR-002**: on a mismatch — the error `touchid pq: NAME does not open after sealing, nothing
  changed`. The file and the keychain item do not change.

## Success Criteria

- **SC-001**: `tests/run.sh` passes (the 033 tests go through the check).
- **SC-002**: manual on the owner's Mac: `secret touchid pq` on the real store, then
  `post-quantum: on` and `secret run` reads a value. Date — when done.
