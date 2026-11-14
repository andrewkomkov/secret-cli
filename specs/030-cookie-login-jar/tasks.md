# Tasks: session-only cookie через расширение Safari и cookie-jar

**Input**: `specs/030-cookie-login-jar/spec.md` (вариант B)

## Этап 1 — jar-инфраструктура (без GUI, тестируемо)

- [x] T001 убрать вариант A: `helper/login/`, команда `cmd_cookie login`, её usage, сборка в `install.sh`, её тесты и доки
- [x] T002 [US1] `secret cookie import --as NAME`: jar из stdin → base64 → хранилище, `-x` и комментарий `cookie jar ... via safari extension`
- [x] T003 [US2] `cmd_run --cookie-jar NAME [--update]`: временный файл 0600, `$SECRET_COOKIE_JAR`, trap-удаление, round-trip `--update`, маска по cookie
- [x] T004 [US3] `cookie ls --jar NAME` (без значений), `cookie pull DOMAIN --all --as NAME` (постоянные cookie домена), `secret-cookies jar DOMAIN`
- [x] T005 [US3] подсказка про расширение при типовых session-именах
- [x] T006 фикс маски: пропуск значений короче 4 символов (или цифры ≤3), один warning в stderr
- [x] T007 hook `hooks/claude-pretooluse.sh`: блок чтения `$SECRET_COOKIE_JAR` и путей jar
- [x] T008 `tests/run.sh`: формат jar, round-trip `--update`, маска по cookie, короткие значения, hook, протокол `import`
- [x] T009 README, README.ru, сайт, `docs/claude-md-secrets.md`: `import`, `--cookie-jar`, `pull --all`, выбор между `pull` и расширением

## Этап 2a — тестируемое ядро (без GUI)

- [x] T010 [US1] loopback-демон `helper/bridge/` (swiftc): `127.0.0.1` фиксированный порт, приём только с loopback, `POST /jar?as=NAME` с токеном → `secret cookie import` из stdin, иначе отказ
- [x] T011 [US1] `secret cookie bridge token|start|stop`: токен и порт в `~/.local/state/secret/bridge.json` (0600); сборка демона в `install.sh`
- [x] T012 [US1] веб-часть `app/extension/`: manifest v3 (право `cookies`), popup/JS — чтение `cookies.getAll` активного домена, сборка Netscape jar, POST на loopback с токеном
- [x] T013 `tests/run.sh`: протокол демона по `curl` — верный токен сохраняет jar, неверный токен и не-loopback отклоняются
- [x] T014 README, README.ru, сайт, `docs/claude-md-secrets.md`: демон, `bridge token`, установка расширения, доступ по сайтам, спарка токена

## Этап 2b — Xcode-обёртка расширения (ручная сборка)

- [x] T015 Xcode-приложение расширения через `xcrun safari-web-extension-converter app/extension`, подпись, сборка в `app/`
- [x] T016 2026-11-11 переводы `ru` строк расширения: `_locales/en|ru/messages.json`, `i18n.js`, проверки ключей в `tests/run.sh`. Вид в Safari с русским языком системы — не проверен руками

## Ручные проверки

- [x] T017 ручная, 2026-11-04: расширение включено, токен спарен, на portal.example.org кнопка сохранила jar из 13 cookie, включая session-only `ASP.NET_SessionId`
- [x] T018 ручная, 2026-11-04: `run --cookie-jar TAX_SESSION --update` — curl шлёт `ASP.NET_SessionId`, авторизован: `/app/Notifications` даёт 200 (MainPage.aspx 302 ведёт в кабинет, не на Login)
- [x] T019, 2026-11-04: удалены мусорные секреты `TAX_USER_TOKEN`, `TAX_COOKIE_COMMITSTATUS`, `TAX_COOKIE_ISEMP` (с подтверждением владельца)
