# Data Model: хранилище data protection keychain

**Запись** — generic password, `kSecUseDataProtectionKeychain`.

| Атрибут | Значение |
|---|---|
| `kSecAttrAccessGroup` | `TEAM.secretcli.<team>.store` (Test: `TEAM.secretcli.<team>.store-test`) |
| `kSecAttrAccount` | `secret-cli` (Test: `secret-cli-test.<прогон>`) |
| `kSecAttrService` | имя, `^[A-Za-z_][A-Za-z0-9_.-]*$` |
| `kSecAttrLabel` | имя |
| `kSecAttrDescription` | `secret-cli` |
| `kSecAttrComment` | комментарий, одна строка |
| `kSecAttrGeneric` | `expires=YYYY-MM-DD` или пусто |
| `kSecAttrAccessControl` | `WhenUnlockedThisDeviceOnly` + `.userPresence` (Test: без него) |
| `kSecValueData` | значение, одна строка UTF-8 |

**Политика** — запись `__secret-cli.policy`: значение `v1 grace=N`, комментарий `grace=N` для
показа. Агент верит только значению, которое прочитал после Touch ID.

**Файл режима** — `~/.local/state/secret/store`, содержимое `dp`. Нет файла — файловый keychain.

**Срок helper** — `build/SecretStore.expires`: секунды Unix окончания profile, пишет `install.sh`.

**Переходы режима**: `file` → `migrate --backup FILE` → `dp` → `migrate --back` → `file`.
