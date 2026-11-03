# Contract: команда `secret lease`

```text
secret lease [--for DURATION] NAME...    аренда имён; DURATION: Nm или Nh, по умолчанию 8h, до 24h
secret lease [--for DURATION] -e FILE    аренда имён из ссылок secret:NAME в FILE
secret lease status                      имена и время конца, без значений и без Touch ID
secret lease --revoke                    закончить все аренды
```

## Вывод

- `lease` (stderr): `leased until 2026-11-04 03:15: SHOP_API_KEY, SHOP_DB_PASSWORD`.
- `lease status` (stdout), по строке на имя: `NAME<TAB>YYYY-MM-DD HH:MM`. Без аренды —
  пустой вывод и `no lease` в stderr, код 0.
- `lease --revoke` (stderr): `lease revoked`.

## Ошибки

| Случай | Сообщение | Код |
|---|---|---|
| `--for` больше 24h или неверный вид | `lease: --for must be 1m..24h` | 64 |
| нет имён | `lease needs NAME... or -e FILE` | 64 |
| имя не найдено | `not found: NAME` | 3 |
| файловый keychain | `lease needs the secure enclave store` | 1 |
| экран заблокирован | `lease needs Touch ID: the screen is locked` | 6 |
| `SECRET_NO_DIALOG=1` | `Touch ID confirmation needed, SECRET_NO_DIALOG is set` | 5 |
| отказ Touch ID | как сейчас у `read` | 1 |
| чтение вне аренды при блокировке | `not leased: A, B` | 6 |

## Окно Touch ID

`secret: lease SHOP_API_KEY, SHOP_DB_PASSWORD for 6h` (список длиннее 5 имён: первые 5 и
`and N more`).

## Протокол агента (внутренний)

- `lease<TAB>nodialog<TAB>hex(reason)<TAB>seconds<TAB>hex(name),...` → `ok<TAB>end_epoch`
- `lease-status` → `ok<TAB>hex(name):end_epoch,...`
- `revoke` → `ok`
- `read` → `ok<TAB>values<TAB>sources`, sources: `l` или `g` на каждое имя.

## Строка статуса для SecretBar

`secret-vault status` получает поле `lease=N:END_EPOCH` (N имён, ближайший конец). Старое поле
`grace=` остаётся.
