# Tasks: постквантовая защита хранилища Secure Enclave

**Input**: `specs/033-pq-vault/spec.md`, `plan.md`

- [x] T001 2026-11-11 конституция 2.5.0: гибрид P-256 + ML-KEM-768 в «Технических ограничениях», отдельный коммит
- [x] T002 [US1] `VaultKeys`, `VaultHeader`: поля `kpub`, `kse`; `seal`/`unseal` v2; `pqSupported()`
- [x] T003 [US1] новое хранилище создаёт ключ ML-KEM; `SECRET_TEST_NO_PQ=1` в тестовой сборке
- [x] T004 [US1] `requirePresence` для обоих ключей; `readDoc` берёт ключ ML-KEM из заголовка, если в записи его ещё нет (заголовок подтверждает ключ файла); `repair` с `kpub`, `kse`
- [x] T005 [US2] команды helper `pq` и `pq-status`
- [x] T006 [US2][US3] `secret touchid pq`, вторая строка `touchid status`, usage. В completion `_secret` подкоманд `touchid` нет и раньше не было, не добавлял
- [x] T007 тесты PQ в `tests/run.sh`, пропуск при `unsupported`
- [x] T008 README, README.ru, сайт: формат хранилища и `touchid pq`
- [x] T009 2026-11-11 CI PR #11: `macos-15` (Swift 6.1.2) пишет `skip 033`, 525 из 525; `macos-26` (Swift 6.3.3) — тесты 033 идут и проходят
- [x] T010 ручная SC-003, 2026-11-14: на Mac владельца, хелпер с проверкой 036. `secret touchid pq`: одно окно Touch ID, 160 значений. `run` с тремя именами работает, статус `post-quantum: on`
