# Tasks: импорт cookie из Safari в хранилище

**Input**: `specs/027-safari-cookie-import/spec.md`

- [x] T001 [US1] `helper/cookies/main.swift`: парсер `.binarycookies`, подкоманды `list DOMAIN` и `value DOMAIN NAME [PATH]`, тестовый путь из `SECRET_TEST_COOKIES`, код `77` на `EPERM`/`EACCES`
- [x] T002 [US1] `helper/cookies/build.sh` по образцу `helper/store/build.sh`: `Release`/`Test`, подпись, `*.src-sha256`
- [x] T003 [US1] `bin/secret`: `cmd_cookie`, ветка `cookie)` в диспетчере, `secret cookie ls DOMAIN`, печать таблицы, гейт Full Disk Access с открытием панели Настроек
- [x] T004 [US2] `secret cookie pull DOMAIN NAME --as SECRET [--path PATH]`: значение пайпом в запись хранилища, `-x` из даты протухания, комментарий `safari cookie DOMAIN NAME`, проверка имени как у `set`
- [x] T005 `install.sh`: сборка хелпера cookies рядом со store; без `swiftc` — сообщение о недоступности
- [x] T006 [US1][US2] `tests/run.sh`: синтетический `.binarycookies` как фикстура, проверка списка имён и извлечения значения, без Safari и Full Disk Access
- [x] T007 README, README.ru, сайт `site/`: команда `secret cookie`, требование Full Disk Access, предел in-memory cookie
- [x] T008 `docs/claude-md-secrets.md`: правило для агента по `secret cookie` (импорт сессии вместо чтения значения)
- [x] T009 ручная, 2026-11-03: `secret cookie ls google.com` на реальном Safari даёт верные имена, флаги (`HSID` — только `HTTPOnly`, `NID`/`__Secure-1PSID` — `Secure,HTTPOnly`) и даты; гейт FDA даёт код 77 без доступа. Так нашли и починили баг: тег страницы — big-endian (парсер читал little-endian, фикстура повторяла ошибку). `pull` в реальный Secure Enclave с целевой cookie владелец выполняет сам — конвейер покрыт тестами в файловом режиме.
