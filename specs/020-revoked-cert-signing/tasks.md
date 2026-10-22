# Tasks: сборка без отозванного сертификата

**Input**: `specs/020-revoked-cert-signing/spec.md`

- [x] T001 2026-10-22: владелец создал в Xcode новый сертификат Apple Development (serial `433D60E5…`) и удалил отозванный
- [x] T002 [US1] `helper/store/build.sh`, `app/build.sh`: сертификат по SHA-1, без отозванного
- [x] T003 [US1] 2026-10-22, Mac владельца: `./install.sh --app` пересобрал SecretBar с новым сертификатом, `codesign --verify` проходит, SecretBar запущен. `secret run --mask` прочитал значение
- [x] T004 `tests/run.sh`: 309 из 309
