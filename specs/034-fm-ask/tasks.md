# Tasks: поиск секрета по смыслу моделью на устройстве

**Input**: `specs/034-fm-ask/spec.md`, `plan.md`

- [x] T001 [US1] `secret ls --ask QUERY [-l]` в `bin/secret`: части по 40, схема с `enum`, `fm respond -m system`
- [x] T002 [US1] фильтр имён по части, порядок ответа, код 1 при пустом ответе
- [x] T003 [US2] без `fm` или при ошибке `fm`: код 2, причина и совет
- [x] T004 тесты с заглушкой `fm` в `tests/run.sh`
- [x] T005 usage, completion, README, README.ru, `docs/claude-md-secrets.md`. Сайт не менял: на нём нет списка команд `ls`
- [x] T006 ручная SC-002, 2026-11-11: настоящий `/usr/bin/fm` (AFM 3 Core Advanced) на Mac владельца, временный keychain, 5 вымышленных секретов. «пароль базы магазина» → `SHOP_DB_PASSWORD` (3,5 с), «почта» → `BILLING_SMTP_PASS`, «where do I keep the S3 credentials» → `ETL_S3_KEY`. «kubernetes» с первой инструкцией дал ложное имя, со второй — пусто (замер в spec.md)
