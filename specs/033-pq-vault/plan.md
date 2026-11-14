# Implementation Plan: post-quantum protection of the Secure Enclave store

**Spec**: `specs/033-pq-vault/spec.md`

## Technical Context

### helper/store/main.swift

- `VaultKeys` and `VaultHeader`: new fields `kpub: Data?` (the ML-KEM-768 public key) and
  `kse: Data?` (the wrapped Secure Enclave key; in the test build, the seed of a software key).
  Old JSON without the fields gives `nil`.
- The ML-KEM code is under `#if compiler(>=6.2)` and `if #available(macOS 26, *)`. Swift 6.1 (CI
  `macos-15`) builds the helper without ML-KEM. The function `pqSupported()` tells whether there
  is support.
- `seal(plain, name, pub, kpub)`: with `kpub`, format v2; otherwise v1, as before.
  v2: `0x02 | ct (1088) | eph (65) | AES-GCM`. Key:
  `HKDF-SHA256(ikm: ecdh || mlkem, salt: eph || ct, info: "secret-cli vault v2|" + name)`.
- `unseal(blob, name, se, kse, ctx)`: first byte `0x04` is v1, `0x02` is v2. v2 needs `kse`,
  otherwise the error `this helper cannot open post-quantum values`.
- `requirePresence`: checks `.userPresence` on the P-256 key and, for v2, on the ML-KEM key.
- New store: `newKemKey()` when supported. The test build with `SECRET_TEST_NO_PQ=1` does not
  create an ML-KEM key.
- `readDoc`: if the keychain item has no ML-KEM key and the header has one, the helper takes it
  from the header. The file key confirms the header. So the grace agent and the gap between the
  file write and the keychain item write work. Different ML-KEM keys in the item and the header
  are an error.
- `repair`: takes `kpub`, `kse` from the header.
- New helper command `pq`: under the store lock, it creates the ML-KEM key (if there is none),
  saves it to the keychain item and the header, asks for Touch ID (`confirmedContext`), opens
  each v1 value and seals it in v2. Also `check` and `wm`. The mark `r` stays.
- New helper command `pq-status`: `on`, `off`, `partial N M`, `unsupported`. Without Touch ID.

### bin/secret

- `touchid_store`: `pq` calls `"$STORE" pq`; `status` prints a second line
  `post-quantum: ...` from `pq-status`.
- Usage.

### Tests (tests/run.sh)

If `pq-status` gives `unsupported`, the PQ tests write `skip` and do not fail.

- new store: `pq-status` = `on`; the first byte of a value in the file cannot be checked (the
  file is encrypted), so the check goes through `pq-status`.
- `SECRET_TEST_NO_PQ=1`: store v1, `pq-status` = `off`.
- `touchid pq`: one Touch ID question, `pq-status` = `on`, values, comments, expiry dates are
  equal.
- repeated `touchid pq`: no question.
- a lease from before the migration survives the migration.
- Touch ID refusal: the values stay v1 and are readable.
- `touchid status` prints the line `post-quantum:`.

## Constitution Check

- **I**: the values go only between the helper and the Secure Enclave. There is no value output.
- **II**: the migration asks for Touch ID once. The ML-KEM key is created with `.userPresence`.
- **III**: only CryptoKit from macOS. `swiftc` from the Command Line Tools.
- **IV**: test build: a software ML-KEM key in the run directory.
- **V**: new subcommand `touchid pq`. `touchid status` gets a second line — see the deviation
  below. The store format v1 is always readable.

## Complexity Tracking

| Deviation | Reason |
|---|---|
| `touchid status` prints a second line | The protection status of the store is part of the status. SecretBar does not parse the `touchid status` output. The first line does not change. |
| Constitution: "Technical constraints" name only ECIES P-256 | Amendment 2.5.0 in a separate commit: hybrid P-256 + ML-KEM-768. |
