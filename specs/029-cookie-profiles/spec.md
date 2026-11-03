# Feature Specification: cookie из всех профилей Safari

**Feature Branch**: `029-cookie-profiles`. Работа идёт в `main`.

**Created**: 2026-11-03

**Status**: Draft 2026-11-03

**Input**: Баг-репорт владельца: `secret cookie ls`/`pull` читают только дефолтный профиль
(`Library/Cookies/Cookies.binarycookies`). Cookie каждого другого профиля лежат в
`Library/WebKit/WebsiteDataStore/<UUID>/Cookies/Cookies.binarycookies`. Вход на сайт в другом
профиле — и команда cookie не находит.

## Контекст и границы

- Safari держит дефолтный профиль в `Cookies/`, а каждый другой — в `WebsiteDataStore/<UUID>/`.
- Пустой или отсутствующий файл профиля пропускается, это не ошибка.
- Фича меняет только хелпер `secret-cookies` и команду `secret cookie`. Формат `.binarycookies`,
  разбор и прочие команды не меняются.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - ls видит все профили (Priority: P1)

1. **When** человек выполняет `secret cookie ls DOMAIN`, **Then** команда печатает cookie этого
   домена из дефолта и всех профилей. Новая колонка `PROFILE` называет профиль (`default` или UUID).
2. **When** у профиля нет файла cookie, **Then** команда его пропускает и код выхода 0.
3. **When** задан `--profile ID`, **Then** команда читает только этот профиль. Неизвестный ID — код 1
   и сообщение `no Safari profile`.

### User Story 2 - pull берёт верный cookie (Priority: P1)

1. **When** одинаковый cookie есть в нескольких профилях, **Then** `pull` берёт cookie с самой
   поздней датой протухания (это самый свежий вход). Дата и комментарий секрета — из того же cookie.
2. **When** у имени несколько путей или несколько доменов, **Then** это ошибка (код 3), как раньше.
3. **When** задан `--profile ID`, **Then** `pull` берёт cookie этого профиля.
4. Комментарий секрета содержит домен, имя cookie и профиль.

## Requirements *(mandatory)*

- **FR-001**: `secret-cookies` читает дефолтный файл и каждый
  `WebsiteDataStore/*/Cookies/Cookies.binarycookies`. Нет файла — профиль пропускается.
- **FR-002**: у каждого cookie есть профиль (`default` или UUID). `list` печатает его колонкой.
- **FR-003**: флаг `--profile ID` у `ls` и `pull` читает один профиль.
- **FR-004**: новая команда хелпера `which DOMAIN NAME [PATH]` печатает `profile<TAB>expiry`
  выбранного cookie. `pull` зовёт `which`, затем `value --profile`, чтобы дата и значение были из
  одного cookie.
- **FR-005**: при одинаковом cookie в нескольких профилях `value`/`which` берут самую позднюю дату.
  Несколько путей или доменов для имени — ошибка (код 3).
- **FR-006**: `secret-cookies path` печатает `profile<TAB>file` для каждого файла.
- **FR-007**: значение cookie не печатается ни в `list`, ни в `which`, ни в `path`, ни в
  комментарии. Значение отдаёт только `value`.
- **FR-008**: тестовая сборка читает каталог из `SECRET_TEST_SAFARI` вместо реального Safari.

## Success Criteria *(mandatory)*

- **SC-001**: cookie, который есть только в профиле, виден в `ls` с UUID, и `pull` кладёт его
  значение в хранилище.
- **SC-002**: при одинаковом cookie в двух профилях `pull` без `--profile` берёт значение с поздней
  датой и ставит её в `-x`.
- **SC-003**: отсутствие каталога `WebsiteDataStore` даёт тот же результат, что и в 1.3.0.
- **SC-004**: значение cookie остаётся вне `list`, `which`, `path` и комментария.
