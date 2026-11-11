# Implementation Plan: постквантовая защита хранилища Secure Enclave

**Spec**: `specs/033-pq-vault/spec.md`

## Technical Context

### helper/store/main.swift

- `VaultKeys` и `VaultHeader`: новые поля `kpub: Data?` (открытый ключ ML-KEM-768) и
  `kse: Data?` (обёртка ключа Secure Enclave, в тестовой сборке — seed программного ключа).
  Старый JSON без полей даёт `nil`.
- Код ML-KEM стоит под `#if compiler(>=6.2)` и `if #available(macOS 26, *)`. Swift 6.1 (CI
  `macos-15`) собирает helper без ML-KEM. Функция `pqSupported()` говорит, есть ли поддержка.
- `seal(plain, name, pub, kpub)`: при `kpub` — формат v2, иначе v1, как раньше.
  v2: `0x02 | ct (1088) | eph (65) | AES-GCM`. Ключ:
  `HKDF-SHA256(ikm: ecdh || mlkem, salt: eph || ct, info: "secret-cli vault v2|" + name)`.
- `unseal(blob, name, se, kse, ctx)`: первый байт `0x04` — v1, `0x02` — v2. Для v2 нужен `kse`,
  иначе ошибка `this helper cannot open post-quantum values`.
- `requirePresence`: проверяет `.userPresence` у ключа P-256 и, для v2, у ключа ML-KEM.
- Новое хранилище: `newKemKey()` при поддержке. Тестовая сборка с `SECRET_TEST_NO_PQ=1` ключ
  ML-KEM не создаёт.
- `readDoc`: если в записи keychain нет ключа ML-KEM, а в заголовке есть, helper берёт его из
  заголовка. Ключ файла подтверждает заголовок. Так агент grace и окно между записью файла и
  записи keychain работают. Разные ключи ML-KEM в записи и заголовке — ошибка.
- `repair`: берёт `kpub`, `kse` из заголовка.
- Новая команда helper `pq`: под блокировкой хранилища создаёт ключ ML-KEM (если его нет),
  сохраняет его в запись keychain и заголовок, спрашивает Touch ID (`confirmedContext`), открывает
  каждое значение v1 и закрывает его в v2. `check` и `wm` тоже. Метка `r` остаётся.
- Новая команда helper `pq-status`: `on`, `off`, `partial N M`, `unsupported`. Без Touch ID.

### bin/secret

- `touchid_store`: `pq` вызывает `"$STORE" pq`; `status` печатает вторую строку
  `post-quantum: ...` из `pq-status`.
- Usage.

### Тесты (tests/run.sh)

Если `pq-status` даёт `unsupported`, тесты PQ пишут `skip` и не падают.

- новое хранилище: `pq-status` = `on`, первый байт значения в файле нельзя проверить (файл
  зашифрован), поэтому проверка через `pq-status`.
- `SECRET_TEST_NO_PQ=1`: хранилище v1, `pq-status` = `off`.
- `touchid pq`: один вопрос Touch ID, `pq-status` = `on`, значения, комментарии, сроки равны.
- повторный `touchid pq`: без вопроса.
- аренда до перевода переживает перевод.
- отказ Touch ID: значения остаются v1 и читаются.
- `touchid status` печатает строку `post-quantum:`.

## Constitution Check

- **I**: значения идут только между helper и Secure Enclave. Вывода значений нет.
- **II**: перевод спрашивает Touch ID один раз. Ключ ML-KEM создаётся с `.userPresence`.
- **III**: только CryptoKit из macOS. `swiftc` из Command Line Tools.
- **IV**: тестовая сборка — программный ключ ML-KEM в каталоге прогона.
- **V**: новая подкоманда `touchid pq`. `touchid status` получает вторую строку — отступление
  ниже. Формат хранилища v1 читается всегда.

## Complexity Tracking

| Отступление | Причина |
|---|---|
| `touchid status` печатает вторую строку | Статус защиты хранилища — часть статуса. SecretBar вывод `touchid status` не разбирает. Первая строка не меняется. |
| Конституция: «Технические ограничения» называют только ECIES P-256 | Поправка 2.5.0 в отдельном коммите: гибрид P-256 + ML-KEM-768. |
