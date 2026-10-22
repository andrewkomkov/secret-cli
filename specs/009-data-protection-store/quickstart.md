# Quickstart: проверка хранилища data protection keychain

Нужно: Xcode, Apple ID в Xcode → Settings → Accounts (Personal Team).

1. `./install.sh` — в выводе `store helper: build/SecretStore.app (profile until ...)`.
2. `tests/run.sh` — каждый тест выводит `ok`, раздел `009` не пропущен.
3. `secret migrate --backup ~/secrets-before-dp.bak` — пароль копии, один Touch ID на чтение
   старых значений, один Touch ID на сверку. Вывод `migrate: N secrets in the data protection store`.
4. `secret ls -l` — без Touch ID, те же имена, комментарии, сроки.
5. `secret get NAME` — один Touch ID. Второй `get` в течение grace — без вопроса.
6. `secret lock`, затем `secret get NAME` — снова Touch ID.
7. `secret touchid status` — `store: dp`, grace, срок profile.
8. `./install.sh --launchd` — `launchctl print gui/$UID/secretcli.renew` показывает задачу.
9. Откат: `secret migrate --back` — записи снова в `secrets.keychain-db`.
