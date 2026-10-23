# Feature Specification: выход на международный рынок

**Feature Branch**: `024-global-launch`. Работа идёт в `main`.

**Created**: 2026-10-23

**Status**: In progress

**Input**: Владелец: «давай на международный рынок выноси и рекламный лендос с motion design и CI на
Action и release-please».

## User Scenarios & Testing *(mandatory)*

### User Story 1 - English first (Priority: P1)

Разработчик из любой страны открывает репу, читает README, ставит команду и SecretBar.

1. **When** человек открывает репу, **Then** README на английском. Русская версия — `README.ru.md`,
   ссылки между версиями в шапке.
2. **When** язык macOS не русский, **Then** SecretBar показывает интерфейс на английском.
3. **When** язык macOS русский, **Then** SecretBar показывает интерфейс на русском, как раньше.
4. Сообщения команды `secret` уже на английском и не меняются.
5. `secret version` и `secret --version` печатают версию.

### User Story 2 - CI и релизы (Priority: P1)

1. **When** приходит push в `main` или pull request, **Then** GitHub Actions на macOS запускает
   `tests/run.sh` (с helper и SecretBar), проверяет синтаксис скриптов. Красный прогон видно в PR.
2. **When** в `main` приходят коммиты `feat`/`fix`, **Then** release-please открывает PR релиза с
   новой версией и `CHANGELOG.md`.
3. **When** владелец сливает PR релиза, **Then** появляется тег `vX.Y.Z` и GitHub Release. Формула в
   tap получает новые `url` и `sha256`, CI tap запускает `brew install` и `brew test`.
4. **When** в репе нет секрета `HOMEBREW_TAP_TOKEN`, **Then** шаг формулы пропускается с
   предупреждением, релиз не падает.

### User Story 3 - Лендинг (Priority: P2)

1. **When** человек открывает `https://andrewkomkov.github.io/secret-cli/`, **Then** страница на
   английском объясняет продукт за один экран: агент работает с именами, значения не видит.
2. Анимации показывают поток: скрытый ввод → Secure Enclave → `run --mask` → `***`. Терминал в
   hero печатает команды. Блоки появляются при прокрутке.
3. **When** в системе включено «уменьшить движение», **Then** анимации выключены, весь текст виден.
4. Страница работает на ширине телефона, в светлой и тёмной теме, без сборки и без трекеров.
5. **When** в `site/` приходит push в `main`, **Then** Actions публикует страницу в GitHub Pages.

### Edge Cases

- Fork без секретов: CI проходит, шаг формулы пропущен.
- Тест SecretBar на runner без сертификата Apple Development: подпись ad-hoc, selftest проходит.
- Строка интерфейса без перевода: SecretBar показывает английский текст.

## Requirements *(mandatory)*

- **FR-001**: README на английском, `README.ru.md` на русском, одно содержание.
- **FR-002**: SecretBar: язык разработки — английский, String Catalog с переводом `ru` для каждой
  строки интерфейса, App Intents и уведомлений.
- **FR-003**: `secret version` печатает `secret X.Y.Z`. Строка версии в `bin/secret` помечена для
  release-please.
- **FR-004**: `.github/workflows/ci.yml`: `tests/run.sh` на macOS runner, `bash -n` для скриптов.
- **FR-005**: `.github/workflows/release.yml`: release-please (тип `simple`, теги `vX.Y.Z`), затем
  обновление формулы в tap токеном `HOMEBREW_TAP_TOKEN`.
- **FR-006**: CI в tap: `brew install --build-from-source`, `brew test`, `brew audit --strict`.
- **FR-007**: `site/`: статическая страница (HTML, CSS, JS без сборки), анимации на CSS и
  Web Animations API, `prefers-reduced-motion`, светлая и тёмная тема, скриншоты SecretBar.
- **FR-008**: `.github/workflows/pages.yml` публикует `site/` в GitHub Pages.
- **FR-009**: в новых файлах нет данных владельца (конституция, «Порядок работы»).

## Success Criteria *(mandatory)*

- **SC-001**: CI зелёный на `main`.
- **SC-002**: release-please открыл PR релиза.
- **SC-003**: страница открывается по адресу Pages, Lighthouse: доступность 90 и выше.
- **SC-004**: SecretBar с `-AppleLanguages (en)` и `(ru)` — без строк другого языка (скриншоты).

## Assumptions

- Спеки и конституция остаются на русском: это рабочие документы владельца.
- Токен для tap создаёт владелец (fine-grained PAT, Contents: write на `homebrew-secret`) и кладёт его
  командой `secret gh HOMEBREW_TAP_TOKEN -R andrewkomkov/secret-cli`.
