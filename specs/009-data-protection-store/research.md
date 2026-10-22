# Research: хранилище data protection keychain

<!-- утр-100: 8.7 — номера версий macOS и Xcode -->
Пробы 2026-10-07 на macOS 27.0, Xcode 27.0. Проба — маленький `.app` (`spike/`), записи с service
`secret-cli-dp-probe`. После каждой пробы мы удалили её записи.

| # | Проверка | Результат |
|---|---|---|
| R1 | `SecItemAdd` с `kSecUseDataProtectionKeychain`, бинарник с ad-hoc-подписью | `-34018` (`errSecMissingEntitlement`) |
| R2 | То же, `.app` с подписью Apple Development бесплатной Personal Team и `keychain-access-groups` | `0`, чтение `0` |
| R3 | Срок profile Personal Team для macOS | 7 дней (`CreationDate` 2026-10-07, `ExpirationDate` 2026-10-14) |
| R4 | `keychain-access-groups` в profile | `TEAM.*`: любой бинарник команды получает любую группу команды. Подписать бинарник без вопросов может любой процесс пользователя (`xcodebuild` подписал пробу без окна) |
| R5 | Запись с `SecAccessControl(.userPresence)`; чтение с `LAContext.interactionNotAllowed` | запись `0`; чтение без окна `-25308`, окна нет |
| R6 | Атрибуты (`kSecReturnAttributes`) записи с `.userPresence` без контекста | в пробе прочитаны без окна. Неверно для рабочего хранилища: keychain спрашивает Touch ID (011 R12) |
| R7 | `SecItemUpdate` атрибутов или значения без Touch ID | `-25308`: изменение требует Touch ID |
| R8 | `SecItemDelete` без Touch ID | `0`: удаление без Touch ID |
| R9 | `LAContext` после `evaluatePolicy`: чтения через 10 с, 120 с, 290 с, `interactionNotAllowed` после подтверждения | один вопрос Touch ID; чтения через 10 с, 120 с и 290 с — `0` |
| R10 | Один `LAContext` на два чтения подряд | одно окно Touch ID |

## Решения

**Хранилище.** Data protection keychain, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` и
`.userPresence` на каждом значении. Rationale: R4 — подпись не отделяет наш helper от любого
бинарника, который подпишет агент. Защиту даёт только проверка Touch ID в самой системе (R5).

Alternatives: записи без `.userPresence` и Touch ID в helper, как в 007. Это решение отклонено.
Причина: агент собирает свой бинарник с той же группой и читает значение. Touch ID ему не нужен.

**Grace.** Процесс-агент helper держит подтверждённый `LAContext` (R9) и отвечает через
unix-сокет `~/.local/state/secret/agent.sock` (каталог 0700). Контекст нельзя передать в другой
процесс, поэтому первый Touch ID спрашивает сам агент. Alternatives:

- метка-файл с кодом аутентификации (HMAC) из 007 не работает. Значение требует Touch ID системы.
  Метка его не заменяет.
- без grace — вопрос на каждый `secret run`.

**Запись.** Новое значение: удалить старую запись и добавить новую (R8, без Touch ID), как
`security add-generic-password -U` раньше. Комментарий и срок: `SecItemUpdate` через агент с
подтверждённым контекстом (R7).

**Выбор хранилища.** Файл режима, а не запись в хранилище. Если profile истёк и helper не
запускается, команда должна сообщить об ошибке. Тихий переход на файловый keychain запрещён.

**Сборка.** `xcodebuild -allowProvisioningUpdates` с `DEVELOPMENT_TEAM`. Team ID — поле `OU`
сертификата `Apple Development` в login keychain. Bundle ID `secretcli.<team>.store`: он уникален
у Apple без личного имени в репе. `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`: если нет
`get-task-allow`, отладчик не может подключиться к helper. Hardened runtime включён.

**Продление.** `install.sh --renew` удаляет локальный profile этого bundle ID и пересобирает
helper, когда до конца срока меньше 3 дней. LaunchAgent запускает это раз в день. Проверка, что
новый profile получает новый срок, — ручная, 2026-10-11 или позже (T-задача в `tasks.md`).
