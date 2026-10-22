# Contract: SecretStore

Вызов: `build/SecretStore.app/Contents/MacOS/SecretStore COMMAND ...`. Hex — строчные цифры, `-`
— пустое поле.

Коды выхода:

- Код 0 — успех.
- Код 1 — ошибка.
- Код 3 — нет записи.
- Код 4 — запись без защиты.
- Код 5 — нет подтверждения Touch ID, или Touch ID нужен при `SECRET_NO_DIALOG=1`.
- Код 64 — неверный вызов.

Имена `__secret-cli.*` принимает только `policy`. Команды `read`, `write`, `attrs`, `delete` и агент
отклоняют эти имена.

| Команда | Touch ID | Вывод |
|---|---|---|
| `list` | нет | `NAME<TAB>COMMENT<TAB>EXPIRY` по строке, сортировка по имени, `-` для пустого; записи `__secret-cli.*` скрыты |
| `has NAME` | нет | код 0 или 3 |
| `read REASON NAME...` | да, через агент | `hex(value)` по строке на имя, в порядке имён |
| `write` | нет | stdin: строки `hex(name) hex(value) hex(comment) hex(expiry)`; запись заменяется |
| `attrs REASON NAME COMMENT EXPIRY` | да, через агент | — |
| `delete NAME...` | нет | код 3, если записи нет |
| `policy show` | нет | `grace=N` из атрибута политики, `none` |
| `policy init [N]` | нет | первая политика пустого хранилища; если политика есть, не меняется; хранилище с записями без политики — ошибка (grace 0, менять — `policy grace`) |
| `policy grace N` | да, всегда новый, в самом клиенте | политика переписывается, агент завершается; новый grace действует со следующего Touch ID |
| `lock` | нет | агент завершается |
| `profile` | нет | конец profile, секунды Unix |
| `agent` | — | внутренняя: процесс-агент |
| `wipe` | нет | только сборка `Test`: удалить все записи account прогона |

## Протокол агента

Сокет `~/.local/state/secret/agent.sock` (сборка `Test`: `$SECRET_TEST_STATE/agent.sock`).
Запрос — одна строка, поля через символ табуляции (TAB), ответ — одна строка.

- `read<TAB>nodialog 0|1<TAB>hex(reason)<TAB>hex(name),hex(name)...` → `ok<TAB>hex(value),...`
- `attrs<TAB>nodialog<TAB>hex(reason)<TAB>hex(name)<TAB>hex(comment)<TAB>hex(expiry)` → `ok`
- `lock` → `ok`, агент завершает работу
- ошибка → `err<TAB>code<TAB>message`

Агент проверяет uid клиента (`getpeereid`). Первый запрос после старта или после конца grace
спрашивает Touch ID. Агент читает политику с этим контекстом. Grace 0 — агент завершает работу
после ответа. Без подтверждённого контекста агент завершает работу через 30 секунд простоя.
