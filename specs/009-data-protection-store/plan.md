<!-- ste: E1.1 — заголовок задан шаблоном spec-kit -->
# Implementation Plan: Хранилище data protection keychain

**Branch**: `009-data-protection-store` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Summary <!-- slop: заголовок задан шаблоном spec-kit -->

Новый helper `SecretStore.app` работает с data protection keychain через `SecItem*`. Значения
защищены `.userPresence`: Touch ID проверяет система (research R4, R5). `bin/secret` выбирает
хранилище по файлу режима. В режиме `dp` все операции идут через helper.

Grace держит
процесс-агент helper с подтверждённым `LAContext`. Переезд: `secret migrate --backup FILE` и
`secret migrate --back`. Profile Personal Team живёт 7 дней. `install.sh --renew` и LaunchAgent
продлевают его.

## Technical Context

<!-- утр-100: 8.7, E8.3 — подпись задана шаблоном spec-kit, номера версий -->
**Language/Version**: Swift 6.4 в режиме Swift 5, bash 3.2

**Primary Dependencies**: Security (`SecItem*`, `SecAccessControl`), LocalAuthentication,
Foundation. Xcode 27 (`xcodebuild`), сертификат Apple Development бесплатной Personal Team.

**Storage**: data protection keychain. Файл режима `~/.local/state/secret/store`.

**Testing**: `tests/run.sh`. Тестовая сборка helper (конфигурация `Test`, `SECRET_TEST`) в
`build/test/`. Если Xcode или Personal Team нет, тесты пропущены с сообщением.

**Target Platform**: macOS 14+ на Apple silicon и Intel с Touch ID или паролем Mac

<!-- утр-100: 1.9, E1.9 — CLI — общепринятое имя типа проекта в шаблоне spec-kit -->
**Project Type**: CLI (bash) и helper (`.app`)

<!-- утр-100: E8.7 — русский текст, десятичная запятая -->
**Performance Goals**: `ls`, `has`, `check` на 300 записях — не медленнее файлового режима
(008: `check` 0,62 с). Чтение в grace — меньше 0,2 с.

**Constraints**: значения только через stdin и stdout (принцип I). Без платного аккаунта (III).

<!-- утр-100: E8.3 — подпись задана шаблоном spec-kit -->
**Scale/Scope**: сотни записей, один пользователь, один Mac

## Constitution Check

| Принцип | Как соблюдается |
|---|---|
| I | значения: bash ↔ helper — stdin/stdout в hex; helper ↔ агент — unix-сокет 0600 в каталоге 0700 |
| II | `.userPresence` на каждом значении, Touch ID спрашивает система; grace ≤ 3600; `SECRET_NO_DIALOG=1` — ошибка без окна |
| III | исключение из 1.1.0: `.app`, `xcodebuild`, Personal Team; без Xcode — файловый keychain как раньше |
| IV | тестовая сборка: свой bundle ID и access group, account на прогон, удаление в конце; без Xcode тесты хранилища пропускаются с сообщением |
| V | все команды и `secret:NAME` прежние; новое хранилище включает `migrate`; обратный путь `migrate --back` |

## Project Structure

### Documentation (this feature)

```text
specs/009-data-protection-store/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/helper-cli.md   # команды SecretStore и протокол агента
└── spike/                    # пробы R1–R10
```

<!-- ste: E2.1 — заголовок задан шаблоном spec-kit -->
### Source Code (repository root)

```text
helper/
├── secret-auth.swift                       # файловый keychain, без изменений
└── store/
    ├── main.swift                          # новый helper (Xcode: код верхнего уровня только в main.swift)
    ├── SecretStore.entitlements            # keychain-access-groups
    ├── SecretStore.xcodeproj/project.pbxproj  # конфигурации Release и Test
    └── build.sh                            # сборка для install.sh и tests/run.sh
bin/secret                                  # выбор хранилища, migrate, ветки dp
install.sh                                  # сборка, --renew, --launchd
hooks/claude-pretooluse.sh                  # новые переменные и прямой вызов helper
tests/run.sh                                # тесты на тестовой сборке
build/SecretStore.app, build/SecretStore.expires, build/SecretStore.src-sha256
```

## Complexity Tracking

| Отступление | Причина |
|---|---|
| Сборка через Xcode и Personal Team (III) | без entitlement data protection keychain недоступен (R1); исключение записано в конституции 1.1.0 |
| `touchid off` и `unlock` в режиме `dp` ведут себя иначе (V) | защита задана системой на каждой записи; своей блокировки у хранилища нет |
| `note`, `expire` в режиме `dp` спрашивают Touch ID (V) | система требует Touch ID для изменения записи (R7) |
| Процесс-агент живёт после команды | контекст Touch ID нельзя передать между процессами (R9) |
| Тестовая сборка отличается от рабочей (`SECRET_TEST`) | Touch ID нельзя нажать в тесте; код теста не попадает в Release |
