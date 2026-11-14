# Implementation Plan: build without the revoked certificate

**Spec**: `specs/020-revoked-cert-signing/spec.md`

## Technical Context

`security find-identity -v -p codesigning` marks the revoked certificate with
`(CSSMERR_TP_CERT_REVOKED)` and shows it all the same. `codesign -s "Apple Development"` with two
certificates of the same name refuses: the name is ambiguous, and `build.sh` signed ad-hoc.
The scripts take the SHA-1 of the first `Apple Development` line without `CSSMERR`.

The helper signature requirement: `certificate leaf[subject.CN] = "Apple Development: ..."`. A new
certificate of the same Apple ID has the same name, the keychain item of the store accepts it.

## Constitution Check

- III: only `security`, `awk`, `codesign`. The signature is the owner's certificate, otherwise ad-hoc.
- IV: `tests/run.sh` builds SecretBar and runs `--selftest`.
- V: the commands do not change.

## Complexity Tracking

No deviations.
