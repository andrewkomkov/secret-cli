# Implementation Plan: выход на международный рынок

**Spec**: `specs/024-global-launch/spec.md`

## Technical Context

- SecretBar: `developmentRegion = en`, `knownRegions = (en, ru, Base)`. Строки в коде — английские.
  `Text`, `Button`, `Label` переводятся сами (LocalizedStringKey). Строки типа `String` (тосты,
  статус, уведомления) — через `String(localized:)`. Перевод `ru` — `Localizable.xcstrings`.
  Фразы App Shortcuts остаются в коде на двух языках. Ключи сверяются с `.stringsdata` сборки.
- Метка проекта без префикса — `Parse.other` вместо строки «Другое».
- `bin/secret`: `VERSION="1.1.0" # x-release-please-version`, команды `version`, `--version`.
- release-please: `release-please-config.json` (`release-type: simple`,
  `include-component-in-tag: false`, `extra-files: [bin/secret]`), `.release-please-manifest.json`
  `1.1.0`, `bootstrap-sha` — последний коммит 1.1.0. GitHub Releases для 1.0.0 и 1.1.0 нет,
  release-please считает от `bootstrap-sha`.
- Тег от `GITHUB_TOKEN` не запускает другие workflows, поэтому формула обновляется в том же
  workflow: job `formula` после `release_created`.
- Права Actions в репе: `default_workflow_permissions=write`,
  `can_approve_pull_request_reviews=true` (нужно release-please для PR).
- Pages: `build_type=workflow`, `actions/deploy-pages`.
- Лендинг: `site/index.html`, `site/style.css`, `site/main.js`, `site/img/`. Шрифты — системные и
  JetBrains Mono с Google Fonts. Скриншоты — `SecretBar --snapshot` на английском.

## Constitution Check

- I, II: не меняются. CI работает на временном keychain, значений нет.
- III: Actions, release-please, Pages — инфраструктура репы, не зависимость команды.
- IV: `tests/run.sh` — тот же, теперь и в CI.
- V: команды не меняются, `version` — новая команда. Язык SecretBar следует языку системы.

## Complexity Tracking

| Отступление | Причина |
|---|---|
| Интерфейс SecretBar на английском при не русском языке системы | Международный рынок, просьба владельца |
| Версию и тег ставит release-please, а не владелец руками | Просьба владельца |
