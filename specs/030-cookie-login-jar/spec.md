# Feature Specification: session-only cookie через расширение Safari и cookie-jar

**Feature Branch**: `030-cookie-login-jar`. Работа идёт в `main`.

**Created**: 2026-11-04

**Status**: Draft 2026-11-04 (вариант B — расширение Safari; вариант A с окном WKWebView отклонён)

**Input**: Запрос соседней сессии (случай 2026-11-04): кабинет eservices.rs.ge (ASP.NET WebForms)
держит сессию на `ASP.NET_SessionId` — HttpOnly session cookie без срока. Safari его в
`Cookies.binarycookies` не пишет, через `document.cookie` его читать нельзя (HttpOnly). `secret
cookie pull` берёт только постоянные cookie, и запрос к `MainPage.aspx` даёт 302 на `Login.aspx`.
Владелец выбрал B: читать cookie из **настоящей** сессии Safari, без второго окна и без повторного
входа.

## Цель

Агент получает рабочую сессию сайта из уже открытой в Safari вкладки: без логина в чате, без пароля,
без показа значений. Вход, пароль и SMS раньше выполнил сам человек в своей Safari.

## Контекст и границы

- Session-only и HttpOnly cookie живут в памяти Safari. Их читает только тот, кто внутри Safari.
  Это расширение Safari с правом `cookies`.
- Правило репозитория «без платного аккаунта и без entitlements» закрывает app groups. Поэтому
  `SafariWebExtensionHandler` из песочницы в хранилище писать не может. Мост идёт через loopback:
  **расширение → 127.0.0.1 (сервер SecretBar) → SecretBar → `secret cookie import`**.
- Ручные шаги делает человек: включает расширение в Safari, даёт доступ к cookie по сайтам, один
  раз вставляет токен спарки из SecretBar в настройки расширения.
- Переиспользуется из общей инфраструктуры: формат jar, хранение jar в секрете (base64), `secret
  run --cookie-jar`, маска по каждому cookie, hook на jar-файл, `cookie ls --jar`, `cookie pull
  --all`.
- Вне рамок: Chrome и Arc (значения зашифрованы Chrome Safe Storage), обход капчи и 2FA (их всегда
  проходит человек).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - захват сессии из Safari (Priority: P1)

1. **When** человек на нужной вкладке Safari нажимает кнопку расширения, **Then** расширение читает
   cookie домена вкладки (включая HttpOnly и session), собирает Netscape jar и шлёт его на loopback
   SecretBar с токеном спарки.
2. **When** SecretBar принял jar с верным токеном, **Then** он зовёт `secret cookie import --as
   NAME` и сохраняет jar как один секрет (base64). Имя берётся из запроса расширения.
3. **When** токен неверный или запрос не с loopback, **Then** SecretBar отклоняет запрос и cookie
   не сохраняет.
4. Значения не идут ни в stdout, ни в лог. `secret log` фиксирует запись. Запись требует
   подтверждения, как `set`.

### User Story 2 - запуск команды с jar (Priority: P1)

1. **When** человек выполняет `secret run --cookie-jar NAME -- cmd`, **Then** команда пишет jar во
   временный файл 0600, путь — в `$SECRET_COOKIE_JAR`. Пример:
   `curl -b "$SECRET_COOKIE_JAR" -c "$SECRET_COOKIE_JAR"`.
2. **When** `cmd` завершена, **Then** команда удаляет файл, в том числе по trap на сигналы.
3. **When** задан `--update`, **Then** после `cmd` команда сохраняет изменённый jar обратно в секрет.
4. Маска покрывает значение каждого cookie из jar. Подтверждение имён — одним запросом Touch ID.

### User Story 3 - осмотр и постоянные cookie (Priority: P2)

1. **When** человек выполняет `secret cookie ls --jar NAME`, **Then** команда печатает имена,
   домены, флаги и expiry cookie внутри jar, без значений.
2. **When** человек выполняет `secret cookie pull DOMAIN --all --as NAME`, **Then** команда собирает
   постоянные cookie домена из файлов Safari (все профили, 029) в один jar. Это путь, когда сессия
   всё-таки персистентная.
3. **When** `pull` или `import` видят типовые session-имена (`ASP.NET_SessionId`, `.ASPXAUTH`,
   `JSESSIONID`, `PHPSESSID`), а на диске их нет, **Then** команда печатает подсказку про расширение.

## Requirements *(mandatory)*

- **FR-001**: расширение Safari (Web Extension) с правом `cookies` читает cookie активного домена,
  собирает Netscape jar. Таргет Xcode в составе SecretBar. Подпись — как у SecretBar.
- **FR-002**: SecretBar держит loopback-сервер на `127.0.0.1` со случайным портом и токеном спарки.
  Принимает jar только с верным токеном и только с loopback. Токен человек берёт в SecretBar и
  вставляет в настройки расширения.
- **FR-003**: `secret cookie import --as NAME` читает jar из stdin, кодирует base64, сохраняет как
  секрет. SecretBar зовёт её. Комментарий `cookie jar DOMAIN via safari extension, N cookies,
  session-only: a,b`. Срок — минимум expiry среди постоянных cookie; все session-only → без срока,
  в комментарии `session`.
- **FR-004**: формат jar — Netscape cookie-jar (как у curl, HttpOnly с префиксом `#HttpOnly_`).
- **FR-005**: в секрете jar лежит в base64 (значение однострочное).
- **FR-006**: `secret run --cookie-jar NAME [--update]` пишет jar во временный файл 0600, путь — в
  `$SECRET_COOKIE_JAR`, удаляет файл после `cmd` и по trap; `--update` сохраняет изменённый jar.
- **FR-007**: маска покрывает значение каждого cookie из jar по отдельности.
- **FR-008**: `secret cookie ls --jar NAME` печатает метаданные cookie без значений.
- **FR-009**: `secret cookie pull DOMAIN --all --as NAME` собирает постоянные cookie домена в jar.
- **FR-010**: подсказка про расширение при типовых session-именах без файла на диске.
- **FR-011**: hook `hooks/claude-pretooluse.sh` блокирует чтение `$SECRET_COOKIE_JAR` и путей
  jar-файлов командами `cat`/`head`/`tail`/`less`/`cp` внутри `secret run`.

### Сопутствующий фикс маски коротких значений

- **FR-012**: `--mask` не маскирует значения короче 4 символов (или из одних цифр длиной ≤3).
  Один раз печатает в stderr `mask skipped for short value NAME`. Причина — `isEmp=0` превращал
  `302` из `curl -w "%{http_code}"` в `3***2`.

## Success Criteria *(mandatory)*

- **SC-001**: на вкладке eservices.rs.ge кнопка расширения сохраняет jar с `ASP.NET_SessionId`
  через SecretBar и `secret cookie import`.
- **SC-002**: `secret run --mask --cookie-jar RSGE_SESSION --update -- curl -s -o /dev/null -w
  '%{http_code}' -b "$SECRET_COOKIE_JAR" -c "$SECRET_COOKIE_JAR"
  https://eservices.rs.ge/MainPage.aspx` даёт `200`, а не 302.
- **SC-003**: ни одна команда не печатает значения. Тесты покрывают формат jar, round-trip
  `--update`, маску по cookie, правило коротких значений, hook и протокол `import` (без живого
  расширения).
- **SC-004**: `docs/claude-md-secrets.md`, раздел «How to import a browser session», описывает
  расширение, `import`, `--cookie-jar` и выбор между `pull` и расширением.
