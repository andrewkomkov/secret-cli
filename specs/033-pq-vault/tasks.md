# Tasks: post-quantum protection of the Secure Enclave store

**Input**: `specs/033-pq-vault/spec.md`, `plan.md`

- [x] T001 2026-11-11 constitution 2.5.0: hybrid P-256 + ML-KEM-768 in "Technical constraints", a separate commit
- [x] T002 [US1] `VaultKeys`, `VaultHeader`: fields `kpub`, `kse`; `seal`/`unseal` v2; `pqSupported()`
- [x] T003 [US1] a new store creates an ML-KEM key; `SECRET_TEST_NO_PQ=1` in the test build
- [x] T004 [US1] `requirePresence` for both keys; `readDoc` takes the ML-KEM key from the header if the item does not have it yet (the header confirms the file key); `repair` with `kpub`, `kse`
- [x] T005 [US2] helper commands `pq` and `pq-status`
- [x] T006 [US2][US3] `secret touchid pq`, the second line of `touchid status`, usage. The `_secret` completion has no `touchid` subcommands and did not have them before; not added
- [x] T007 PQ tests in `tests/run.sh`, skip on `unsupported`
- [x] T008 README, README.ru, site: the store format and `touchid pq`
- [x] T009 2026-11-11 CI of PR #11: `macos-15` (Swift 6.1.2) writes `skip 033`, 525 of 525; `macos-26` (Swift 6.3.3) — the 033 tests run and pass
- [x] T010 manual SC-003, 2026-11-14: on the owner's Mac, a helper with the 036 check. `secret touchid pq`: one Touch ID window, 160 values. `run` with three names works, status `post-quantum: on`
