# Tasks: Touch ID

**Input**: `specs/004-touch-id/` (spec.md, plan.md)

- [x] T001 `helper/secret-auth.swift`: `auth` и `status`
- [x] T002 `install.sh`: сборка в `build/secret-auth`, `build/` в `.gitignore`
- [x] T003 [US2] `is_unlocked` через helper
- [x] T004 [US1] Конфиг, `secret touchid on|off|status|grace`, подмены только для keychain с другим inode
- [x] T005 [US1] `require_auth` в `get`, `copy`, `run`, `export`, отметка времени и grace
- [x] T006 [US1] Хук: правила FR-007
- [x] T007 Тесты с заглушкой helper (SC-001), подмены с keychain по умолчанию не работают, правила хука **2026-10-02**: нашлась ошибка — без helper в пределах grace проверка пропускалась; исправлено
- [ ] T008 [US2] Тесты на заблокированном keychain через helper (SC-002, первый прогон — ручная проверка окна) **2026-10-02**: тест проходит; что окна не было, владелец ещё не подтвердил
- [ ] T009 [US1] Ручная проверка Touch ID на Mac владельца (SC-003)
- [x] T010 README, `secret help`, `docs/claude-md-secrets.md`, раздел Secrets в `~/.claude/CLAUDE.md`
