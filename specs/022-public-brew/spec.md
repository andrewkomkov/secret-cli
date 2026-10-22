# Feature Specification: открытая репа и установка через Homebrew

**Feature Branch**: `022-public-brew`. Работа идёт в `main`.

**Created**: 2026-10-22

**Status**: Done 2026-10-22

**Input**: Владелец: «нужно чтоб наш софт был в открытой репе и устанавливался через brew».
Владелец потребовал убрать из репы и истории все упоминания работодателя. Старую историю
удалить, в открытой репе оставить один коммит.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Установка одной командой (Priority: P1)

1. **When** человек запускает `brew install andrewkomkov/secret/secret`, **Then** Homebrew ставит
   команду `secret` и автодополнение zsh. Затем Homebrew собирает helper Touch ID и helper
   хранилища Secure Enclave.
2. `brew upgrade` ставит новую версию. Если helper хранилища изменился и подпись у него ad-hoc,
   команда просит одно касание `secret touchid repair`.
3. SecretBar и хук Claude Code человек ставит сам: `$(brew --prefix secret)/libexec/install.sh
   --app --claude-hook`. Для SecretBar нужен Xcode.

### User Story 2 - Открытая репа без личного (Priority: P1)

1. В файлах и в истории нет имени работодателя, его проектов, личных путей и имён секретов
   владельца.
2. История начинается с одного коммита, автор — личный адрес владельца.
3. Полная старая история лежит только на Mac владельца, в bundle-файле.

## Requirements *(mandatory)*

- **FR-001**: публичная репа `github.com/andrewkomkov/secret-cli`, лицензия MIT.
- **FR-002**: tap `github.com/andrewkomkov/homebrew-secret`, формула `secret`, сборка из исходника
  тега.
- **FR-003**: SecretBar ищет ссылки `secret:NAME` в каталоге из настройки `projectsDir`, по
  умолчанию в домашнем каталоге.
- **FR-004**: демо-данные, тесты и документы используют вымышленные проекты.

## Success Criteria *(mandatory)*

- **SC-001**: на чистом префиксе `brew install` и `brew test` проходят.
- **SC-002**: поиск по репе и истории не находит слов из списка запретов.
- **SC-003**: `tests/run.sh` проходит целиком.

## Assumptions

- Пользователь brew работает на macOS с Command Line Tools: Homebrew без них не работает.
- У пользователя обычно нет сертификата Apple Development. Тогда helper получает подпись ad-hoc.
