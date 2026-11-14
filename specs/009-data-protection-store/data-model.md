# Data Model: data protection keychain store

**Item**: generic password, `kSecUseDataProtectionKeychain`.

| Attribute | Value |
|---|---|
| `kSecAttrAccessGroup` | `TEAM.secretcli.<team>.store` (Test: `TEAM.secretcli.<team>.store-test`) |
| `kSecAttrAccount` | `secret-cli` (Test: `secret-cli-test.<run>`) |
| `kSecAttrService` | name, `^[A-Za-z_][A-Za-z0-9_.-]*$` |
| `kSecAttrLabel` | name |
| `kSecAttrDescription` | `secret-cli` |
| `kSecAttrComment` | comment, one line |
| `kSecAttrGeneric` | `expires=YYYY-MM-DD` or empty |
| `kSecAttrAccessControl` | `WhenUnlockedThisDeviceOnly` + `.userPresence` (Test: without it) |
| `kSecValueData` | value, one line of UTF-8 |

**Policy**: the item `__secret-cli.policy`: value `v1 grace=N`, comment `grace=N` for display.
The agent trusts only the value that it read after Touch ID.

**Mode file**: `~/.local/state/secret/store`, content `dp`. No file means the file keychain.

**Helper expiry**: `build/SecretStore.expires`: Unix seconds of the profile end, written by `install.sh`.

**Mode transitions**: `file` → `migrate --backup FILE` → `dp` → `migrate --back` → `file`.
