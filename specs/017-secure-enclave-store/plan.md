# Implementation Plan: Secure Enclave store without a signature expiry

**Spec**: `specs/017-secure-enclave-store/spec.md`

## Technical Context

- One source: `helper/store/main.swift`. The `VAULT` flag replaces storage in the keychain with a
  file. The agent, grace, socket, `clip` and the event log are shared.
- Build: `helper/store/build-vault.sh` → `swiftc -D VAULT` → `build/secret-vault`, signature
  `Apple Development` or ad-hoc, `-o runtime`. Test build: `-D VAULT -D SECRET_TEST` →
  `build/test/secret-vault-test`.
- Keys:
  - the Secure Enclave key `SecureEnclave.P256.KeyAgreement.PrivateKey`, flags
    `[.privateKeyUsage, .userPresence]`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`;
  - the file key — 32 random bytes (AES-256-GCM);
  - the login keychain item: `M(32) || pub x963(65) || SE key wrapper`. The helper creates it,
    so the default ACL trusts only the helper.
- File: `SCV1 || AES-GCM(file key, JSON)`, AAD `SCV1`. JSON:
  `{"grace": N|null, "check": E, "items": [{"n","c","x","v": E,"r"}]}`. `E` is the ECIES of the value:
  `eph x963 || AES-GCM(HKDF(ECDH, salt: eph, info: "secret-cli vault v1|" + name))`.
  `r` is a random version tag, new on each write of the value.
- `check` is the ECIES of a known text. Confirmation in the release build: decryption of `check`
  with a fresh `LAContext` with `localizedReason`. This is the Touch ID window. After that, the same context decrypts
  the other values without a window. So confirmation and access are one Secure Enclave action.
- Write: `flock` on `vault.lock`, a temporary file, `rename`. The previous version is `vault.prev`.
- `bin/secret`: mode `vault` in the mode file. `is_dp` means any helper store. `STORE`
  is selected by the mode. `store_check` and `touchid status` do not touch the profile in `vault` mode.
  `migrate --vault` and `--dp` are one function for the move between helpers.
- SecretBar: `Paths.store` by the mode. The `vault` mode also turns on the store.

## Protection of the keychain item (probe 2026-10-14)

The security check of the commit flagged a weaker authorization. A probe on a separate
login keychain item showed:

- another program overwrites the data of the item without a prompt (`SecItemUpdate` → 0);
- after that, the owner cannot read the item silently (-128), but can delete it;
- read and delete by another program without a prompt fail (-128, -25244).

Decisions:

- The helper reads the item only silently (`kSecUseAuthenticationUIFail`). A prompt means that
  another program changed the item. Then the helper stops with the error `keyChanged` and does not show the
  keychain password window.
- File: `SCV2 || header length || header || AES-GCM(file key, JSON)`. The header is the public
  key, the SE key wrapper and `wm` (the file key under ECIES to the SE key). The payload cipher authenticates
  the header (AAD).
- `secret touchid repair`: after Touch ID, the helper opens `wm`, checks the payload with this key and
  creates a new keychain item. Damage to the item no longer destroys the secrets.
- Grace is in the keychain item, not in the file. An old copy of the file does not bring back an old grace.
- Before the Touch ID window, the helper checks the SE key with a context without a prompt. If the key works
  without a prompt, it does not have `.userPresence`, and the helper rejects it.
- Without a store file, a changed item is replaced with a new one: there is nothing to protect.
- The live check showed that `kSecUseAuthenticationUIFail` does not remove the password window for
  an item that another program changed. The release build calls
  `SecKeychainSetUserInteractionAllowed(false)` for the whole process. The Touch ID window is not a
  keychain window, it stays.
- The `.userPresence` check is strict: only the LocalAuthentication error −1004
  ("confirmation needed") passes. Any other result is a refusal.
- Accepted risk: a program of the owner can replace both the item and the file with its own Secure
  Enclave key with `.userPresence`. If the owner then runs `repair` and confirms, the helper accepts
  this key. Such a program reads new values only through its own Touch ID window. A place
  that another program cannot overwrite is not available without a profile. A program with such rights
  can also simply change `bin/secret`.
- A rollback of the file to an old copy stays possible. It brings back old items, but each read
  still needs Touch ID.

## Constitution Check

- I: values go through a pipe and stdin, the disk holds only ciphertext.
- II: read needs `.userPresence`. Grace is the same agent.
- III: `swiftc` and system frameworks (CryptoKit, LocalAuthentication, Security).
- IV: tests on the test build with a software key in the run directory.
- V: the commands stay the same, the only new items are the flags `migrate --vault` and `--dp`.

## Complexity Tracking

No deviations.
