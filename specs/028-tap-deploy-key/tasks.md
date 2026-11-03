# Tasks: push формулы tap по SSH deploy key

**Input**: `specs/028-tap-deploy-key/spec.md`

- [x] T001 [US1] `.github/workflows/release.yml`: джоба `formula` — SSH deploy key вместо HTTPS-токена, env `HOMEBREW_TAP_DEPLOY_KEY`, ветка «нет ключа» с warning
- [x] T002 [US2] провиженинг: `ssh-keygen` ed25519, `gh repo deploy-key add --allow-write` на `homebrew-secret`
- [x] T003 [US2] base64 приватного ключа в хранилище под `HOMEBREW_TAP_DEPLOY_KEY` (пайпом, без argv)
- [x] T004 [US2] `secret gh HOMEBREW_TAP_DEPLOY_KEY -R andrewkomkov/secret-cli` (владелец подтверждает в окне), удалить локальные файлы ключа
- [x] T005 проверка права записи ключа: клон tap по SSH и доступ на запись (без релиза)
- [x] T006 ручная, 2026-11-03: релиз 1.4.0 — джоба `formula` сама обновила url и sha256 в tap по SSH deploy key (коммит «secret 1.4.0»), формула встала на v1.4.0, cookies-строка сохранена, tap CI brew install зелёный.