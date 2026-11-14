# Feature Specification: build without the revoked certificate

**Feature Branch**: `020-revoked-cert-signing`. The work goes on in `main`.

**Created**: 2026-10-22

**Status**: Done 2026-10-22

**Input**: On 2026-10-22 macOS did not open the new SecretBar build: "contains malware". The test
`012: selftest` got `Killed: 9`. The owner's Apple Development certificate
(serial `333CCCD6…`) is revoked, OCSP answers `CSSMERR_TP_CERT_REVOKED`. The builds were signed with it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - macOS runs the build (Priority: P1)

1. **Given** the keychain has two Apple Development certificates with the same name, one is revoked.
   **When** `install.sh` builds the helper and SecretBar, **Then** the signature is the valid
   certificate, macOS runs both.
2. **Given** no valid certificate exists, **Then** the signature is ad-hoc, not the revoked certificate.
3. The helper opens the Secure Enclave store right after the rebuild. The new certificate gives
   the same name in the signature requirement, and the keychain item accepts the helper.

## Requirements *(mandatory)*

- **FR-001**: `helper/store/build.sh` and `app/build.sh` select the certificate by SHA-1 and skip
  the revoked one.
- **FR-002**: without a valid certificate, the signature is ad-hoc.

## Success Criteria *(mandatory)*

- **SC-001**: `tests/run.sh` passes in full, `012: selftest` included.
- **SC-002**: on the owner's Mac, `secret` reads secrets after the rebuild of the helper.
