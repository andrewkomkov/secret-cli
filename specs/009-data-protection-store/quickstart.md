# Quickstart: check of the data protection keychain store

Necessary: Xcode, an Apple ID in Xcode → Settings → Accounts (Personal Team).

1. `./install.sh`: the output has `store helper: build/SecretStore.app (profile until ...)`.
2. `tests/run.sh`: each test prints `ok`, the section `009` is not skipped.
3. `secret migrate --backup ~/secrets-before-dp.bak`: the backup password, one Touch ID to read
   the old values, one Touch ID for the comparison. Output `migrate: N secrets in the data protection store`.
4. `secret ls -l`: without Touch ID, the same names, comments, expiry dates.
5. `secret get NAME`: one Touch ID. A second `get` within grace: no question.
6. `secret lock`, then `secret get NAME`: Touch ID again.
7. `secret touchid status`: `store: dp`, grace, profile expiry date.
8. `./install.sh --launchd`: `launchctl print gui/$UID/secretcli.renew` shows the job.
9. Rollback: `secret migrate --back`: the items are in `secrets.keychain-db` again.
