# Tasks: Записи, которые читает только helper

**Input**: `specs/007-protected-items/` (spec.md, plan.md, research.md)

## Phase 1: Helper

- [x] T001 `secret-auth`: `status`, `auth`, общая часть (открыть keychain, выключить UI, найти запись)
- [x] T002 `read KC REASON NAME...`: политика и grace, Touch ID, `not protected` для чужой записи
- [x] T003 `write KC NAME [--comment] [--expiry] [--keep-attrs]`, замена чужой записи через `NAME#new`
- [x] T004 `delete`, `policy init|grace|remove`, отметка grace с HMAC
- [x] T005 Сборка `-D SECRET_TEST`: ответ Touch ID из файла `SECRET_TEST_AUTH`

## Phase 2: bin/secret

- [x] T006 Режим: защищённый, если есть `__secret-cli.policy`; чтение и запись через helper; `__secret-cli.*` скрыты в `ls`
- [x] T007 `touchid on`: политика и перенос всех записей; `touchid off`: возврат в `security`; `touchid grace` через политику; `status`
- [x] T008 Убрать конфиг `~/.config/secret/config` и прежний `require_auth`: Touch ID только в helper

## Phase 3: install.sh

- [x] T009 Ad-hoc подпись с hardened runtime, хэш исходника, перенос старый → новый helper, откат при ошибке

## Phase 4: Тесты

- [x] T010 Защищённая запись: чтение helper, отказ другому бинарнику без окна (SC-001)
- [x] T011 Перенос при обновлении helper (SC-002), прерванный перенос `NAME#new`
- [x] T012 Подменённая запись → `not protected` (SC-003); удалённая политика → grace 0; поддельная отметка
- [x] T013 Прежние тесты в обычном и в защищённом режиме

## Phase 5: Проверка и документы

- [ ] T014 Ручная проверка SC-004 на keychain владельца
- [x] T015 README (модель угроз), `secret help`, `CLAUDE.md`, `docs/claude-md-secrets.md`; хук: убрать правила про конфиг Touch ID, которого больше нет
