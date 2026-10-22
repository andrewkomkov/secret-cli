# Implementation Plan: хранилище Secure Enclave без срока подписи

**Spec**: `specs/017-secure-enclave-store/spec.md`

## Technical Context

- Исходник один: `helper/store/main.swift`. Флаг `VAULT` заменяет хранение в keychain на
  файл. Агент, grace, сокет, `clip`, журнал событий — общие.
- Сборка: `helper/store/build-vault.sh` → `swiftc -D VAULT` → `build/secret-vault`, подпись
  `Apple Development` или ad-hoc, `-o runtime`. Тестовая сборка: `-D VAULT -D SECRET_TEST` →
  `build/test/secret-vault-test`.
- Ключи:
  - ключ Secure Enclave `SecureEnclave.P256.KeyAgreement.PrivateKey`, флаги
    `[.privateKeyUsage, .userPresence]`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`;
  - ключ файла — 32 случайных байта (AES-256-GCM);
  - запись keychain входа: `M(32) || pub x963(65) || обёртка ключа SE`. Её создаёт helper,
    поэтому ACL по умолчанию доверяет только ему.
- Файл: `SCV1 || AES-GCM(ключ файла, JSON)`, AAD `SCV1`. JSON:
  `{"grace": N|null, "check": E, "items": [{"n","c","x","v": E,"r"}]}`. `E` — ECIES значения:
  `eph x963 || AES-GCM(HKDF(ECDH, salt: eph, info: "secret-cli vault v1|" + имя))`.
  `r` — случайная метка версии, новая при каждой записи значения.
- `check` — ECIES известного текста. Подтверждение в release-сборке: расшифровка `check`
  свежим `LAContext` с `localizedReason`. Это окно Touch ID. Дальше тот же контекст расшифровывает
  остальные значения без окна. Так подтверждение и доступ — одно действие Secure Enclave.
- Запись: `flock` на `vault.lock`, временный файл, `rename`. Прежняя версия — `vault.prev`.
- `bin/secret`: режим `vault` в файле режима. `is_dp` — любое хранилище helper. `STORE`
  выбирается по режиму. `store_check` и `touchid status` не трогают profile в режиме `vault`.
  `migrate --vault` и `--dp` — одна функция переезда между helper.
- SecretBar: `Paths.store` по режиму. Режим `vault` тоже включает хранилище.

## Защита записи keychain (проба 2026-10-14)

Проверка безопасности коммита отметила ослабление авторизации. Проба на отдельной записи
keychain входа показала:

- чужая программа без вопроса перезаписывает данные записи (`SecItemUpdate` → 0);
- после этого владелец не читает запись молча (-128), но может её удалить;
- чтение и удаление чужой программой без вопроса не проходят (-128, -25244).

Решения:

- Helper читает запись только молча (`kSecUseAuthenticationUIFail`). Вопрос означает, что
  запись изменила чужая программа. Тогда helper останавливается с ошибкой `keyChanged` и окно
  пароля keychain не показывает.
- Файл: `SCV2 || длина заголовка || заголовок || AES-GCM(ключ файла, JSON)`. Заголовок — открытый
  ключ, обёртка ключа SE и `wm` (ключ файла под ECIES к ключу SE). Шифр payload подтверждает
  заголовок (AAD).
- `secret touchid repair`: после Touch ID helper открывает `wm`, проверяет payload этим ключом и
  создаёт новую запись keychain. Порча записи больше не уничтожает секреты.
- Grace лежит в записи keychain, не в файле. Старая копия файла не возвращает старый grace.
- Перед окном Touch ID helper проверяет ключ SE контекстом без вопроса. Если ключ работает
  без вопроса, у него нет `.userPresence`, и helper его отвергает.
- Без файла хранилища изменённая запись заменяется новой: защищать нечего.
- Живая проверка показала, что `kSecUseAuthenticationUIFail` не убирает окно пароля для
  записи, которую изменила чужая программа. Release-сборка вызывает
  `SecKeychainSetUserInteractionAllowed(false)` для всего процесса. Окно Touch ID — не окно
  keychain, оно остаётся.
- Проверка `.userPresence` строгая: проходит только ошибка LocalAuthentication −1004
  («нужно подтверждение»). Любой другой результат — отказ.
- Принятый риск: программа владельца может подменить и запись, и файл своим ключом Secure
  Enclave с `.userPresence`. Если владелец потом запустит `repair` и подтвердит, helper примет
  этот ключ. Новые значения такая программа прочитает только через своё окно Touch ID. Место,
  которое чужая программа не перезапишет, без profile недоступно. Программа с такими правами
  может и просто изменить `bin/secret`.
- Откат файла к старой копии остаётся возможным. Он возвращает старые записи, но каждое чтение
  по-прежнему требует Touch ID.

## Constitution Check

- I: значения идут через pipe и stdin, на диске только шифр.
- II: чтение требует `.userPresence`. Grace — тот же агент.
- III: `swiftc` и системные фреймворки (CryptoKit, LocalAuthentication, Security).
- IV: тесты на тестовой сборке с программным ключом в каталоге прогона.
- V: команды прежние, новые только флаги `migrate --vault` и `--dp`.

## Complexity Tracking

Нет отступлений.
