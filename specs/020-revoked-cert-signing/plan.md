# Implementation Plan: сборка без отозванного сертификата

**Spec**: `specs/020-revoked-cert-signing/spec.md`

## Technical Context

`security find-identity -v -p codesigning` помечает отозванный сертификат
`(CSSMERR_TP_CERT_REVOKED)` и всё равно его показывает. `codesign -s "Apple Development"` при двух
сертификатах с одним именем отказывает: имя неоднозначное, и `build.sh` подписывал ad-hoc.
Скрипты берут SHA-1 первой строки `Apple Development` без `CSSMERR`.

Требование подписи helper: `certificate leaf[subject.CN] = "Apple Development: ..."`. У нового
сертификата того же Apple ID имя то же, запись keychain хранилища его принимает.

## Constitution Check

- III: только `security`, `awk`, `codesign`. Подпись — сертификат владельца, иначе ad-hoc.
- IV: `tests/run.sh` собирает SecretBar и запускает `--selftest`.
- V: команды не меняются.

## Complexity Tracking

Нет отступлений.
