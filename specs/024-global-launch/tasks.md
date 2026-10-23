# Tasks: выход на международный рынок

**Input**: `specs/024-global-launch/spec.md`

- [x] T001 [US1] `bin/secret`: `VERSION`, `secret version`, `--version`, usage, completion, тест
- [x] T002 [US1] SecretBar: английские строки в коде, `Parse.other`, `developmentRegion = en`
- [x] T003 [US1] SecretBar: `Localizable.xcstrings` с `ru`, ключи сверены со сборкой
- [x] T004 [US1] 2026-10-23: снимки `--snapshot` на `en` и `ru`, строк другого языка нет. Экран настроек показывает путь команды, на сайт он не идёт
- [x] T005 [US1] `README.md` на английском, `README.ru.md`, комментарии в `hooks/` и автодополнении
- [x] T006 [US2] `.github/workflows/ci.yml`, 2026-10-23: прогон зелёный, 339 проверок на macos-15, SecretBar собран
- [x] T007 [US2] release-please: config, manifest, `.github/workflows/release.yml`, job формулы. 2026-10-23: открыт PR #1 «release 1.2.0»
- [x] T008 [US2] tap: `.github/workflows/test.yml`, 2026-10-23: install, test, audit проходят
- [x] T009 [US2] права Actions в репе, описание и темы репы
- [x] T010 [US3] `site/`: страница, анимации, reduced motion, тема, телефон
- [x] T011 [US3] `.github/workflows/pages.yml`, Pages включены, страница открывается. Lighthouse 2026-10-23: светлая тема 100/100/100/100, тёмная — производительность 94, остальное 100
- [x] T012 конституция 2.3.0, `CLAUDE.md` (порядок релиза)
- [ ] T013 ручная: владелец кладёт `HOMEBREW_TAP_TOKEN`, PR релиза слит, формула обновилась
- [x] T014 `install.sh`: повтор `open` после -600 сразу после `pkill`, установка доходит до шага хука. 2026-10-23: `./install.sh --claude-hook --app` на Mac владельца — SecretBar из новой сборки запущен
