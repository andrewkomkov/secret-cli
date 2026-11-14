# Tasks: build without the revoked certificate

**Input**: `specs/020-revoked-cert-signing/spec.md`

- [x] T001 2026-10-22: the owner created a new Apple Development certificate in Xcode (serial `433D60E5…`) and deleted the revoked one
- [x] T002 [US1] `helper/store/build.sh`, `app/build.sh`: certificate by SHA-1, without the revoked one
- [x] T003 [US1] 2026-10-22, owner's Mac: `./install.sh --app` rebuilt SecretBar with the new certificate, `codesign --verify` passes, SecretBar is running. `secret run --mask` read a value
- [x] T004 `tests/run.sh`: 309 of 309
