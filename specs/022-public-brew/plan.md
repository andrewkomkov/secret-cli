# Implementation Plan: открытая репа и установка через Homebrew

**Spec**: `specs/022-public-brew/spec.md`

## Technical Context

- `bin/secret` находит `build/` по symlink, поэтому работает из `libexec` Homebrew без правок.
- Формула: `libexec.install` всего дерева без `tests`, `specs`, `.specify`, `.claude`. Сборка
  `helper/store/build.sh Release libexec/build` и `swiftc helper/secret-auth.swift`. Symlink
  `bin/secret`, `zsh_completion`. `test do`: `secret help`, `secret ls` на временном keychain.
- `install.sh` остаётся для установки из клона, SecretBar и хука.
- SecretBar: `Paths.projects` читает `UserDefaults` `projectsDir`, иначе `~`. Владелец ставит
  своё значение командой `defaults write`.
- Чистка: демо-данные SecretBar, README, `docs/claude-md-secrets.md`, тесты, спека 013.
- Формула лежит только в tap.
- Публикация: bundle старой истории в `~/secret-cli-history.bundle`, новая `.git`, один коммит,
  `gh repo create --public`, тег `v1.0.0`, tap с формулой и sha256 архива тега.
- Конституция 2.2.0: «Remote не добавляется» заменяет «remote — публичная репа на GitHub,
  в ней нет данных владельца».

## Constitution Check

- I, II: не меняются.
- III: Homebrew — способ установки, а не зависимость. Команда работает на системных утилитах.
- IV: `tests/run.sh` проходит. `brew install` и `brew test` проверены руками.
- V: команды и пути не меняются. `projectsDir` по умолчанию даёт `~` вместо прежнего каталога
  владельца — отступление, см. ниже.

## Complexity Tracking

| Отступление | Причина |
|---|---|
| Путь поиска ссылок SecretBar стал настройкой | Прежний путь называл каталог работодателя. Владелец ставит его в `projectsDir` |
| Remote на GitHub | Просьба владельца, конституция 2.2.0 |
