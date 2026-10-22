# Feature Specification: сборка без отозванного сертификата

**Feature Branch**: `020-revoked-cert-signing`. Работа идёт в `main`.

**Created**: 2026-10-22

**Status**: Done 2026-10-22

**Input**: 2026-10-22 macOS не открыла новую сборку SecretBar: «contains malware». Тест
`012: selftest` получил `Killed: 9`. Сертификат Apple Development владельца
(serial `333CCCD6…`) отозван, OCSP отвечает `CSSMERR_TP_CERT_REVOKED`. Сборки подписывались им.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - macOS запускает сборку (Priority: P1)

1. **Given** в keychain два сертификата Apple Development с одним именем, один отозван.
   **When** `install.sh` собирает helper и SecretBar, **Then** подпись — действующий
   сертификат, macOS запускает оба.
2. **Given** действующего сертификата нет, **Then** подпись ad-hoc, а не отозванный сертификат.
3. Helper открывает хранилище Secure Enclave сразу после пересборки. Новый сертификат даёт
   то же имя в требовании подписи, и запись keychain принимает helper.

## Requirements *(mandatory)*

- **FR-001**: `helper/store/build.sh` и `app/build.sh` выбирают сертификат по SHA-1 и пропускают
  отозванный.
- **FR-002**: без действующего сертификата подпись ad-hoc.

## Success Criteria *(mandatory)*

- **SC-001**: `tests/run.sh` проходит целиком, `012: selftest` в том числе.
- **SC-002**: на Mac владельца `secret` читает секреты после пересборки helper.
