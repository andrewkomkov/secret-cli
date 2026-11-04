# Tasks: cookie import сливает jar

**Input**: `specs/031-cookie-jar-merge/spec.md`

- [x] T001 [US1] `cmd_cookie import`: при существующем секрете читать старый jar и слить с новым по ключу `domain|path|name`, новый ключ побеждает
- [x] T002 [US1] пересчёт комментария и `-x` по итоговому набору после мёржа
- [x] T003 [US2] флаг `--replace`: перезапись без чтения старого секрета и без Touch ID
- [x] T004 usage/доки: README, README.ru, сайт, `docs/claude-md-secrets.md` — мёрж по умолчанию, `--replace`
- [x] T005 `tests/run.sh`: мёрж двух доменов, обновление ключа без дубликатов, `--replace`, отсутствие значений в выводе
- [ ] T006 ручная на реальном расширении: захват portal + tax в один секрет даёт cookie обоих; дата — при выполнении
