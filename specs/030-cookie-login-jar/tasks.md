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

## Этап 2 — расширение Safari + мост

- [ ] T010 [US1] расширение Safari (Web Extension, право `cookies`): чтение cookie активного домена, сборка Netscape jar, кнопка, настройка имени и токена
- [ ] T011 [US1] loopback-сервер в SecretBar: `127.0.0.1` случайный порт, токен спарки, приём только с loopback, вызов `secret cookie import --as NAME` из stdin
- [ ] T012 [US1] Xcode: таргет расширения в проекте SecretBar, подпись, сборка в `app/build.sh`, интерфейс SecretBar для токена/порта
- [ ] T013 переводы `ru` для новых строк SecretBar и расширения
- [ ] T014 README, сайт: установка и включение расширения, выдача доступа по сайтам, спарка токена

## Ручные проверки

- [ ] T015 ручная: включить расширение в Safari, спарить токен, на portal.example.org нажать кнопку → jar с `ASP.NET_SessionId` в секрете; дата — при выполнении
- [ ] T016 ручная: `secret run --mask --cookie-jar TAX_SESSION --update -- curl ... MainPage.aspx` даёт 200; дата — при выполнении
- [ ] T017 после приёмки: удалить мусорные секреты `TAX_USER_TOKEN`, `TAX_COOKIE_COMMITSTATUS`, `TAX_COOKIE_ISEMP` (с подтверждением владельца)
