# Implementation Plan: импорт cookie из Safari в хранилище

**Spec**: `specs/027-safari-cookie-import/spec.md`

## Technical Context

### Формат `Cookies.binarycookies`

- Путь: `~/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies`.
- Заголовок: magic `cook`, затем `uint32 BE` — число страниц, затем размеры страниц (`uint32 BE`).
- Страница: тег `0x00000100`, `uint32 LE` — число cookie, смещения cookie (`uint32 LE`), footer.
- Запись cookie: размер, флаги (`uint32 LE`: бит 0 — `Secure`, бит 4 — `HTTPOnly`), смещения полей
  (domain, name, path, value), две даты `float64 LE`. Дата — Mac epoch, смещение `978307200`
  секунд от Unix epoch.
- Строки полей — C-строки с нулём на концах по своим смещениям.

### Хелпер `helper/cookies/`

- `helper/cookies/main.swift` — ридер. Парсит файл, фильтрует по домену.
- Подкоманды хелпера:
  - `list DOMAIN` — печатает по строке на cookie: `name<TAB>path<TAB>flags<TAB>expiry`. Значения нет.
  - `value DOMAIN NAME [PATH]` — печатает в stdout только значение одной cookie. Несколько
    совпадений без `PATH` → ошибка с перечнем путей, значения нет.
- `helper/cookies/build.sh Release|Test OUTDIR` — зеркало `helper/store/build.sh`: `swiftc -O`,
  подпись Apple Development или ad-hoc, hardened runtime, запись `*.src-sha256`.
- Тестовая сборка `-D SECRET_TEST`: ридер берёт путь файла из `SECRET_TEST_COOKIES`, а не из Safari.
  Так `tests/run.sh` читает синтетический `.binarycookies` без Safari и без Full Disk Access.

### Гейт Full Disk Access

- Ридер открывает файл. На `EPERM`/`EACCES` выходит кодом `77` (`EX_NOPERM`).
- `bin/secret` ловит код `77`: печатает путь, объясняет Full Disk Access, зовёт
  `open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"`.

### `bin/secret`

- Новый `cmd_cookie` и ветка `cookie)` в диспетчере рядом с прочими.
- `secret cookie ls DOMAIN` → хелпер `list`, печать таблицы.
- `secret cookie pull DOMAIN NAME --as SECRET [--path PATH]`:
  1. хелпер `value DOMAIN NAME [PATH]` отдаёт значение в stdout;
  2. `bin/secret` пайпом передаёт его в ту же запись хранилища, что и `cmd_set`, без argv;
  3. дату протухания из `list` ставит флагом `-x`;
  4. комментарий — `safari cookie DOMAIN NAME`.
- `install.sh` собирает хелпер cookies рядом со store-хелпером. Без `swiftc` команда сообщает, что
  возможность недоступна, остальные команды работают.

## Constitution Check

- **I**: `ls` печатает только имена и метаданные. Значение cookie идёт из хелпера в stdout и пайпом
  в запись хранилища. В argv и логах значения нет. Новой команды с печатью значения нет.
- **II**: запись в хранилище идёт без Touch ID, как у `set`. Чтение секрета позже спросит Touch ID.
  Full Disk Access выдаёт человек в Настройках, команда его не обходит.
- **III**: ридер — Swift-хелпер из исходника в репе, сборка `swiftc` из Command Line Tools, без
  сети и Homebrew. Без собранного хелпера команда сообщает о недоступности.
- **IV**: `tests/run.sh` парсит синтетический `.binarycookies` из `SECRET_TEST_COOKIES`. Проверяет
  список имён и извлечение значения. Safari, реальный файл и Full Disk Access — ручная проверка с
  датой в `tasks.md`.
- **V**: `secret cookie` — новая команда. Прежние команды, формат `secret:NAME`, account и путь
  keychain остаются как есть.

## Complexity Tracking

| Отступление | Причина |
|---|---|
| Новый компилируемый хелпер `helper/cookies/` | Разбор бинарного формата Safari типобезопаснее и тестируемее в Swift, чем в bash. Full Disk Access выдаётся одному подписанному бинарю адресно. Этот же хелпер переиспользует SecretBar. |
| Чтение файла другого приложения (Safari) | Единственный способ достать persistent `HTTPOnly` cookie без рук. Файл принадлежит владельцу, доступ выдаёт он сам через Full Disk Access. |
