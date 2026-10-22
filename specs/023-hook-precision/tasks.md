# Tasks: хук без ложных срабатываний

**Input**: `specs/023-hook-precision/spec.md`

- [x] T001 [US1] `hooks/claude-pretooluse.sh`: тело heredoc у `cat`, `tee`, `git` не проверяется
- [x] T002 [US2] `hooks/claude-pretooluse.sh`: helper хранилища — список программ чтения
- [x] T003 `tests/run.sh`: проверки `023:`, прежние `hook blocks` проходят
- [x] T004 `hooks/install-claude.sh`: хук в `settings.json` и строка `@docs/claude-md-secrets.md` в `CLAUDE.md`. Повторный запуск и новый путь заменяют прежние записи
- [x] T005 `CLAUDE.md` в корне репы, README, конституция 2.2.1
- [x] T006 2026-10-22, Mac владельца: `./install.sh --claude-hook --app`. В `~/.claude/CLAUDE.md` строка импорта правил. Хук пропустил heredoc с текстом `secret touchid repair` и `codesign --verify` helper хранилища
- [ ] T007 Релиз `v1.1.0`, формула в tap, `brew install` и `brew test`
