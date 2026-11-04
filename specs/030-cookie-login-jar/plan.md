# Implementation Plan: session-only cookie через расширение Safari и cookie-jar

**Spec**: `specs/030-cookie-login-jar/spec.md` (вариант B — расширение Safari)

## Этапы

- **Этап 1 — jar-инфраструктура (без расширения).** Общий плумбинг, который работает сам по себе и
  тестируется без GUI. Это основа, на которую встаёт расширение.
- **Этап 2 — расширение Safari + мост.** Захват live-сессии и доставка jar в хранилище.

Вариант A (окно WKWebView, `cookie login`, `helper/login`) отклонён и из дерева удаляется.

## Этап 1: jar-инфраструктура

### Хранение и формат
- Netscape cookie-jar (HttpOnly с префиксом `#HttpOnly_`). В секрете — base64 (значение
  однострочное). Комментарий и `-x` считаются из jar (минимум expiry постоянных cookie; все
  session-only → без `-x`, в комментарии `session`).

### `bin/secret`
- `secret cookie import --as NAME`: читает jar из stdin, кодирует base64, пишет через путь
  `cmd_set` (значение пайпом, не argv), ставит `-x` и комментарий.
- `secret run --cookie-jar NAME [--update]`: jar в `mktemp` 0600, путь в `$SECRET_COOKIE_JAR`,
  `trap` на EXIT/HUP/INT/TERM удаляет файл; `--update` сохраняет изменённый jar. Маска — по каждому
  cookie.
- `secret cookie ls --jar NAME`: метаданные без значений.
- `secret cookie pull DOMAIN --all --as NAME`: постоянные cookie домена из `secret-cookies jar
  DOMAIN` (все профили, 029) в один jar.
- Подсказка про расширение при типовых session-именах.
- Фикс маски FR-012: пропуск значений короче 4 символов (или цифры ≤3), один warning в stderr.

### Hook
- `hooks/claude-pretooluse.sh` блокирует чтение `$SECRET_COOKIE_JAR` и путей jar-файлов.

### Что убрать из дерева (вариант A)
- `helper/login/` (хелпер WKWebView), команда `cmd_cookie login`, её usage, её сборка в
  `install.sh`, её тесты и упоминания в доках. Остальное из работы агента сохранить.

## Этап 2: расширение Safari + мост

### Расширение (Xcode-таргет в составе SecretBar)
- Safari Web Extension, право `cookies` и доступ к хостам. Кнопка на панели: читает
  `browser.cookies.getAll({domain})` активной вкладки (HttpOnly и session), собирает Netscape jar.
- Шлёт jar на loopback SecretBar `POST http://127.0.0.1:PORT/jar` с заголовком токена и полем
  `as=NAME` (имя секрета задаёт человек в настройках расширения или диалоге).
- Подпись — как у SecretBar (Apple Development или ad-hoc). Без подписи Apple Development Safari
  требует «Allow Unsigned Extensions» в меню Develop.

### Мост в SecretBar
- SecretBar поднимает loopback-сервер `127.0.0.1` на случайном порту, принимает только с loopback и
  только с верным токеном спарки. Токен и порт SecretBar показывает в своём интерфейсе.
- На валидный `POST /jar` SecretBar вызывает `secret cookie import --as NAME`, передавая jar в
  stdin. Значение в SecretBar в память надолго не кладётся, в лог не пишется.
- Токен спарки хранится в хранилище как секрет (`SECRETBAR_EXT_TOKEN`) или в UserDefaults SecretBar.

### Ручные шаги (человек)
- Включить расширение в Safari, дать доступ к cookie по сайтам, один раз вставить токен из SecretBar
  в настройки расширения.

## Constitution Check

- **I**: значения cookie не идут в stdout обычных команд, в argv и логи. jar из расширения — по
  loopback в SecretBar, затем в `import` через stdin. `ls --jar` печатает только метаданные.
  Временный jar-файл — 0600, удаляется, hook закрывает чтение.
- **II**: `import` пишет секрет — подтверждение как у `set`. `run --cookie-jar` читает секрет —
  Touch ID одним запросом. Вход в сайт раньше сделал человек в своей Safari.
- **III**: расширение и сервер — часть SecretBar (Xcode, подпись Apple Development или ad-hoc, без
  profile и entitlements). `secret` и хелперы — как раньше. Без SecretBar/расширения доставка не
  работает, прочие команды работают.
- **IV**: `tests/run.sh` проверяет этап 1 без GUI: формат jar, round-trip `--update`, маска,
  короткие значения, hook, протокол `import`. Живое расширение и loopback — ручная проверка с датой.
- **V**: новые команды `cookie import`, `cookie ls --jar`, `cookie pull --all`, флаги `run
  --cookie-jar`/`--update`. Существующие команды и формат `secret:NAME` не меняются.

## Complexity Tracking

| Отступление | Причина |
|---|---|
| Расширение Safari + loopback-мост в SecretBar | Session/HttpOnly cookie читает только код внутри Safari. app groups закрыты правилом «без entitlements», поэтому мост идёт через loopback, а не через песочницу хелпера. |
| jar как один секрет в base64 | Хранилище держит однострочные значения, jar многострочный. |
| `run --update` пишет секрет после `cmd` | ASP.NET крутит сессию. Без сохранения она умирает за ~20 минут. |
| Маска пропускает короткие значения | `isEmp=0` рвал `302` в `3***2`. |
