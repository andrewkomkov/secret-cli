# Feature Specification: post-quantum protection of the Secure Enclave store

**Feature Branch**: `033-pq-vault`

**Created**: 2026-11-11

**Status**: Draft 2026-11-11

**Input**: Owner: "something specific to macOS 27". Research of 2026-11-11: CryptoKit since
macOS 26 gives `SecureEnclave.MLKEM768`, an ML-KEM-768 key inside the Secure Enclave.

## Goal

A value in the store is opened only by the P-256 key from the Secure Enclave. A quantum computer
can compute the private P-256 key from the public key. The public key is in the file header.

The threat "store now, decrypt later": an attacker copies the store file and the login keychain
item now. Later a quantum computer opens the values without Touch ID and without this Mac.

After the feature, each value is sealed with two Secure Enclave keys: P-256 and ML-KEM-768. To
read a value, both keys are needed. A quantum computer breaks only P-256; it does not break the
ML-KEM-768 key.

## Context and scope

- Only the Secure Enclave store. The file keychain does not change.
- The file key (AES-256-GCM) is already resistant to a quantum attack: a symmetric 256-bit key.
- The Secure Enclave creates the ML-KEM-768 key with `.userPresence`, as the P-256 key. One
  Touch ID confirmation opens both keys.
- macOS 26 or later is needed, and a helper built with the macOS 26 SDK or later (Swift 6.2+). An
  old helper and an old macOS work as before.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - a new store is hybrid at once (Priority: P1)

1. **When** the helper creates a new store on macOS 26+, **Then** the helper creates both keys,
   and each value is sealed in the hybrid way (format v2).
2. **When** a person reads a value, **Then** Touch ID is asked once, as before.

### User Story 2 - migration of an old store (Priority: P1)

1. **When** a person runs `secret touchid pq`, **Then** the helper creates an ML-KEM-768 key,
   asks for Touch ID once and seals each old value again in format v2.
2. The values, comments, expiry dates and leases do not change. The value version mark (`r`)
   stays.
3. A repeated `secret touchid pq` migrates only the remaining v1 values. If there are none, the
   command prints `touchid pq: all N values are post-quantum` and does not ask for Touch ID.
4. Until the migration, new values are written in format v1, and reads work as before.

### User Story 3 - status (Priority: P2)

1. `secret touchid status` prints a second line: `post-quantum: on`, `post-quantum: off (secret
   touchid pq)`, `post-quantum: partial N/M (secret touchid pq)` or `post-quantum: unsupported`.
2. The status does not ask for Touch ID.

### Edge Cases

- A helper without ML-KEM support meets a v2 value: the error
  `this helper cannot open post-quantum values: rebuild it on macOS 26 or later`. The value does
  not change.
- `secret touchid repair` restores both keys from the file header.
- A grace agent started before the migration sees the new keys in the header and reads the
  keychain item again.
- An ML-KEM key without `.userPresence` (the item was replaced): an error, as for the P-256 key.

## Requirements

- **FR-001**: format v2 of a value: byte `0x02`, ML-KEM-768 ciphertext (1088 bytes), the P-256
  public key of the ephemeral key (65 bytes), AES-GCM. The AES key is HKDF-SHA256 of
  `ecdh || mlkem` with the salt `eph || ct` and the info `secret-cli vault v2|NAME`.
- **FR-002**: a v1 value starts with `0x04` (x963). The helper reads both formats.
- **FR-003**: the keychain item and the file header keep the ML-KEM public key and the wrapped
  Secure Enclave key. Old items without these fields are readable.
- **FR-004**: `secret touchid pq` is a new subcommand. Without the Secure Enclave store, it fails
  with an error.
- **FR-005**: the test build keeps a software ML-KEM key. `SECRET_TEST_NO_PQ=1` creates a v1 store
  for the migration test.

## Success Criteria

- **SC-001**: tests: a new store gives v2 values; the migration v1 → v2 keeps the values,
  comments, expiry dates and the lease; a repeated migration does nothing; the status is correct.
- **SC-002**: CI on `macos-15` (without ML-KEM) is green: the PQ tests are skipped there.
- **SC-003**: manual check on the owner's Mac: `secret touchid pq` — one Touch ID window, then
  `secret run` works, status `post-quantum: on`.
