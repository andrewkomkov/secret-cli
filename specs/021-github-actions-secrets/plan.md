# Implementation Plan: секрет в GitHub Actions

**Spec**: `specs/021-github-actions-secrets/spec.md`

## Technical Context

- `bin/secret`: `cmd_gh`, `confirm`. Окно — `osascript display dialog` с кнопками «Cancel» и
  «Send», по умолчанию «Cancel».
- `gh secret set NAME` без `--body` читает значение из stdin. Шифрование для GitHub (libsodium
  sealed box) делает `gh`. В macOS нет XSalsa20, поэтому своё шифрование команда не делает.
- Тесты: `SECRET_GH` — путь к поддельному `gh`, `SECRET_CONFIRM=yes|no` — ответ окна. Обе
  переменные работают только через `test_override`, то есть только с тестовым keychain.
- SecretBar: в журнале операция `gh` называется «отправка в GitHub».
- `completions/_secret`, `README.md`, `docs/claude-md-secrets.md`.

## Constitution Check

Конституция 2.1.0 разрешает эту команду:

- I: значение идёт в stdin `gh`, в `argv` его нет.
- II: каждую отправку подтверждает человек в окне. Без окна — ошибка.
- III: `gh` и сеть нужны только `secret gh`.
- IV: проверки в `tests/run.sh` на поддельном `gh`. Окно и живая отправка — ручная проверка.
- V: другие команды не меняются.

## Complexity Tracking

| Отступление | Причина |
|---|---|
| Значение уходит из Mac в GitHub | Просьба владельца. Отправку подтверждает человек, принципы I–III в версии 2.1.0 это описывают |
