# Tasks: cookie из всех профилей Safari

**Input**: `specs/029-cookie-profiles/spec.md`

- [x] T001 [US1] `helper/cookies/main.swift`: `SECRET_TEST_SAFARI` вместо пути файла, `Store`/`stores()`/`load()`, поле `profile` в `Cookie`, код 77 на каталоге без прав
- [x] T002 [US2] `pick()` — выбор одного cookie: несколько путей/доменов → код 3, иначе самая поздняя дата; команда `which`
- [x] T003 [US1] разбор `--profile ID` в argv, `list` с колонкой profile, `value`, `which`, `path` (`profile<TAB>file`)
- [x] T004 [US1][US2] `bin/secret`: `--profile` в `cookie ls`/`pull`, колонка `PROFILE`, pull через `which`→`value --profile`, комментарий с профилем, сообщение 77 без второго `path`
- [x] T005 usage в `bin/secret`: `ls [--profile ID] DOMAIN`, `pull … [--profile ID]`, «самый поздний при нескольких профилях»
- [x] T006 `tests/run.sh`: фикстура-каталог `SECRET_TEST_SAFARI` (дефолт + профиль), случаи 1–10 из баг-репорта
- [x] T007 README, README.ru, сайт, `docs/claude-md-secrets.md`: профили, колонка `PROFILE`, `--profile`
- [ ] T008 ручная на реальном многопрофильном Safari: `ls` видит профиль, `pull` берёт свежий cookie, дата — при выполнении
