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
- [ ] T016 переводы `ru` строк расширения

## Ручные проверки

- [ ] T017 ручная: включить расширение в Safari, спарить токен, на eservices.rs.ge нажать кнопку → jar с `ASP.NET_SessionId` в секрете; дата — при выполнении
- [ ] T018 ручная: `secret run --mask --cookie-jar RSGE_SESSION --update -- curl ... MainPage.aspx` даёт 200; дата — при выполнении
- [ ] T019 после приёмки: удалить мусорные секреты `RSGE_USER_TOKEN`, `RSGE_COOKIE_COMMITSTATUS`, `RSGE_COOKIE_ISEMP` (с подтверждением владельца)
