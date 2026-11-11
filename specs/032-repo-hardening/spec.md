# Feature Specification: защита репы на GitHub

**Feature Branch**: `032-repo-hardening`

**Created**: 2026-11-11

**Status**: Draft 2026-11-11

**Input**: Владелец: «наша репа в гите шикарна? Что-то, может, туда добавить из полезностей
GitHub».

Аудит 2026-11-11: `zizmor` дал 10 находок (8 high, 2 medium): actions без SHA, широкие права,
токен в checkout. У `main` нет защиты. Нет `SECURITY.md` и приватных сообщений об уязвимостях.

Релиз без attestation. CI только на `macos-15` (Swift 6.1), а у владельца Swift 6.4. Из-за этой
разницы баг 1.7.1 нашёлся только в CI.

## Цель

Репа инструмента для секретов сама закрыта от типовых атак на цепочку поставки. Пользователь может
проверить, что tarball релиза собрал workflow этой репы.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - workflows без лишних прав (Priority: P1)

1. **When** `zizmor` проверяет `.github/workflows`, **Then** находок уровня medium и high нет.
2. Каждый `uses:` закреплён полным SHA коммита. Комментарий рядом называет тег.
3. Права выданы на уровне job, а не на весь workflow. `checkout` не сохраняет токен.
4. Dependabot раз в неделю предлагает обновления actions.

### User Story 2 - CI на двух версиях macOS (Priority: P1)

1. **When** идёт push или PR, **Then** `tests/run.sh` проходит на `macos-15` и `macos-26`.
2. CI проверяет `bin/secret` и скрипты через `shellcheck -S warning`.

### User Story 3 - проверяемый релиз (Priority: P2)

1. **When** release-please сделал релиз, **Then** workflow создаёт attestation происхождения для
   tarball тега.
2. `gh attestation verify secret-X.Y.Z.tar.gz -R andrewkomkov/secret-cli` проходит. README
   называет команду.

### User Story 4 - политика безопасности и защита `main` (Priority: P2)

1. `SECURITY.md` говорит, куда писать об уязвимости, и описывает модель угроз коротко.
2. Приватные сообщения об уязвимостях (private vulnerability reporting) включены.
3. Ruleset `main`: нет force-push и удаления ветки. GitHub сливает PR только при зелёном CI. Админ
   репы может обойти правило (владелец пушит в `main` напрямую).
4. Ветка удаляется после слияния PR. Пустая Wiki выключена.

## Requirements

- **FR-001**: действия закреплены SHA, права на уровне job, `persist-credentials: false`.
- **FR-002**: `.github/dependabot.yml`, экосистема `github-actions`, раз в неделю.
- **FR-003**: матрица CI `macos-15`, `macos-26`. `shellcheck` в шаге Syntax.
- **FR-004**: job `attest` в `release.yml`: скачивает tarball тега, `attest-build-provenance`.
- **FR-005**: `SECURITY.md` на английском. README и README.ru: проверка релиза.
- **FR-006**: настройки репы через `gh api`: ruleset, private vulnerability reporting, delete branch
  on merge, wiki off.

## Success Criteria

- **SC-001**: `zizmor --offline .github/workflows` — 0 находок medium/high. `actionlint` чистый.
- **SC-002**: CI зелёный на обеих версиях macOS.
- **SC-003**: следующий релиз: `gh attestation verify` проходит (ручная проверка).
- **SC-004**: `gh api repos/andrewkomkov/secret-cli/rulesets` показывает ruleset `main`.

## Границы

- Команда `secret` не меняется. Формулу tap эта фича не трогает.
- Мажорные версии actions не поднимаются здесь: это сделает Dependabot отдельными PR.
- `macos-27` нет в GitHub Actions на 2026-11-11. Его добавим, когда появится.
