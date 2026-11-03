# Implementation Plan: push формулы tap по SSH deploy key

**Spec**: `specs/028-tap-deploy-key/spec.md`

## Technical Context

### Джоба `formula` в `release.yml`

Было: клон по HTTPS с `HOMEBREW_TAP_TOKEN`. Станет: клон по SSH ключом deploy key.

```yaml
env:
  DEPLOY_KEY: ${{ secrets.HOMEBREW_TAP_DEPLOY_KEY }}   # base64 приватного ed25519
steps:
  - name: No key
    if: env.DEPLOY_KEY == ''
    run: echo "::warning::HOMEBREW_TAP_DEPLOY_KEY is not set. Update the tap by hand."
  - name: Update the tap
    if: env.DEPLOY_KEY != ''
    run: |
      set -euo pipefail
      mkdir -p ~/.ssh && chmod 700 ~/.ssh
      printf '%s' "$DEPLOY_KEY" | base64 -d > ~/.ssh/tap && chmod 600 ~/.ssh/tap
      ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
      export GIT_SSH_COMMAND="ssh -i ~/.ssh/tap -o IdentitiesOnly=yes"
      url="https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz"
      sha="$(curl -fsSL --retry 5 "$url" | sha256sum | cut -d' ' -f1)"
      git clone --depth 1 git@github.com:andrewkomkov/homebrew-secret.git tap
      cd tap
      sed -i -E "s|^  url \".*\"$|  url \"$url\"|; s|^  sha256 \".*\"$|  sha256 \"$sha\"|" Formula/secret.rb
      git config user.name "github-actions[bot]"
      git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
      git commit -am "secret $VERSION"
      git push
```

### Провиженинг ключа (из CLI, вне репы)

1. `ssh-keygen -t ed25519 -N "" -C "homebrew-secret deploy (release.yml)" -f tapkey`.
2. `gh repo deploy-key add tapkey.pub -R andrewkomkov/homebrew-secret --allow-write --title "release.yml tap push"`.
3. `base64 < tapkey | secret set -c "<comment>" HOMEBREW_TAP_DEPLOY_KEY` — приватный ключ идёт в
   хранилище пайпом, без argv. Значение однострочное (base64).
4. `secret gh HOMEBREW_TAP_DEPLOY_KEY -R andrewkomkov/secret-cli` — владелец подтверждает в окне.
5. Удалить `tapkey` и `tapkey.pub`.

Проверка права записи до релиза: `GIT_SSH_COMMAND` с ключом + `git push` пустого коммита в tap,
затем откат. Или `ssh -i tapkey -T git@github.com` и клон по SSH.

## Constitution Check

- **I**: приватный ключ идёт в хранилище пайпом, в argv и логи не попадает. base64 держит значение
  однострочным. `secret gh` отдаёт его только в stdin `gh secret set`.
- **II**: `secret gh` читает значение — это Touch ID и окно подтверждения отправки. Владелец
  подтверждает. Запись `secret set` идёт без Touch ID, как обычно.
- **III**: `ssh-keygen`, `gh`, `base64` есть в системе и уже в зависимостях (`gh` нужен `secret gh`).
- **IV**: `tests/run.sh` проверяет команду `secret`, а не workflow. Правка `release.yml`
  проверяется на следующем релизе — ручная проверка с датой в `tasks.md`.
- **V**: меняется только джоба `formula`. Команды `secret`, формат ссылок и формула не меняются.

## Complexity Tracking

| Отступление | Причина |
|---|---|
| Приватный ключ в base64 | Хранилище держит однострочные значения, а ключ PEM многострочный. base64 — мост. |
| Смена секрета `HOMEBREW_TAP_TOKEN` → `HOMEBREW_TAP_DEPLOY_KEY` | SSH-ключ вместо токена. Старый секрет всё равно отсутствует. |
