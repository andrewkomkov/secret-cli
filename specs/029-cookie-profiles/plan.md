# Implementation Plan: cookie из всех профилей Safari

**Spec**: `specs/029-cookie-profiles/spec.md`

Детальный дизайн с кодом — в баг-репорте владельца (вставка в истории фичи). Здесь — суть.

## Technical Context

### helper/cookies/main.swift

- Путь заменяется на каталог: `SECRET_TEST_SAFARI` (тест) или
  `.../com.apple.Safari/Data/Library` (релиз).
- `struct Store { profile; path }`. `stores()` даёт `default` (`Cookies/Cookies.binarycookies`) и
  по одному на каждый подкаталог `WebKit/WebsiteDataStore/<UUID>` (`.../Cookies/Cookies.binarycookies`).
  Нет каталога `WebsiteDataStore` — только дефолт. Нет прав на каталог — код 77.
- `load(_ Store)` открывает файл: `ENOENT` → пусто (профиль без cookie), `EPERM`/`EACCES` → 77,
  битый файл → 65. Каждому cookie проставляет профиль.
- `Cookie` получает поле `profile`. `parse` не меняется.
- `pick(cs, domain, name, path)` выбирает один cookie: несколько путей или доменов → код 3 (как
  раньше); иначе — cookie с самой поздней датой (`expiry`), это самый свежий вход.
- Разбор `--profile ID` в начале argv. Команды: `list` (колонка profile), `value`, новый `which`
  (`profile<TAB>expiry`), `path` (`profile<TAB>file` на строку).

### bin/secret

- `cookies_run`: сообщение 77 больше не зовёт `path` второй раз (файлов несколько).
- `cmd_cookie ls`: флаг `--profile`, колонка `PROFILE` в таблице.
- `cmd_cookie pull`: флаг `--profile`. Сначала `which` → `profile` и `expiry`, затем
  `value --profile "$profile"` — значение и дата из одного cookie. Комментарий:
  `safari cookie DOMAIN NAME, profile PROFILE`.
- usage: `ls [--profile ID] DOMAIN`, `pull ... [--profile ID]`, «несколько профилей — самый
  поздний».

### Тесты (tests/run.sh)

Тестовая сборка читает `SECRET_TEST_SAFARI` вместо `SECRET_TEST_COOKIES`. Фикстура — каталог с
`Cookies/Cookies.binarycookies` и `WebKit/WebsiteDataStore/<UUID>/Cookies/Cookies.binarycookies`.
Случаи 1–10 из баг-репорта: cookie только в профиле; одинаковый cookie с разными датами (поздняя
побеждает, `-x` из неё); `--profile default`; неизвестный `--profile` (код 1); нет
`WebsiteDataStore`; профиль без файла; битый файл профиля (65); два пути в двух профилях (код 3);
`path` с `default` и UUID; значения нет в `which`/`path`/комментарии.

## Constitution Check

- **I**: значение cookie отдаёт только `value`, пайпом в запись хранилища. `list`, `which`, `path`
  и комментарий значения не печатают.
- **III**: хелпер прежний — Swift из исходника в репе, без сети.
- **IV**: `tests/run.sh` на фикстуре-каталоге, без Safari и Full Disk Access. Проверка на реальном
  многопрофильном Safari — ручная, с датой в `tasks.md`.
- **V**: `secret cookie` та же команда, добавлены флаг `--profile` и колонка `PROFILE`. Формат
  `.binarycookies` и прочие команды не меняются.

## Complexity Tracking

| Отступление | Причина |
|---|---|
| `value` и `which` как два вызова | Значение не должно идти рядом с метаданными. `which` даёт профиль и дату без значения, затем `value --profile` берёт значение из того же профиля. |
