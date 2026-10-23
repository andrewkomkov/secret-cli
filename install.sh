#!/bin/bash
# Ставит secret в ~/.local/bin как symlink на эту репу: правка в репе сразу видна в PATH.
#   ./install.sh                 команда
#   ./install.sh --claude-hook   ещё хук PreToolUse в ~/.claude/settings.json и правила агента в
#                                ~/.claude/CLAUDE.md (hooks/install-claude.sh)
#   ./install.sh --app           ещё приложение SecretBar в ~/Applications и его запуск
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
claude_hook=0; app=0; legacy_only=0
for a in "$@"; do
  case "$a" in
    --claude-hook) claude_hook=1 ;;
    --renew) legacy_only=1 ;;  # the LaunchAgent of the data protection store calls it (018)
    --app) app=1 ;;
    *) echo "install.sh: unknown option $a" >&2; exit 64 ;;
  esac
done

# Хранилища data protection больше нет (018): его LaunchAgent, сборки и profile уходят.
drop_legacy() {
  local plist="$HOME/Library/LaunchAgents/secretcli.renew.plist" f
  if [ -f "$plist" ]; then
    rm -f "$plist"  # first: bootout can stop this script when the agent itself runs it
    launchctl bootout "gui/$(id -u)/secretcli.renew" 2>/dev/null || true
    echo "legacy: LaunchAgent secretcli.renew removed" >&2
  fi
  rm -rf "$root/build/SecretStore.app" "$root/build/test/SecretStoreTest.app"
  rm -f "$root"/build/SecretStore.expires "$root"/build/SecretStore.src-sha256 \
    "$root"/build/test/SecretStoreTest.expires "$root"/build/test/SecretStoreTest.src-sha256 \
    "$HOME/.local/state/secret/agent.sock" "$HOME/.local/state/secret/agent.lock" "$HOME/.local/state/secret/renew.log"
  local profiles="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
  [ -d "$profiles" ] || return 0
  for f in "$profiles"/*.provisionprofile; do
    [ -f "$f" ] || continue
    if security cms -D -i "$f" 2>/dev/null | grep -qE '<string>[A-Z0-9]+\.secretcli\.[a-z0-9]+\.store(-test)?</string>'; then
      rm -f "$f"
      echo "legacy: profile of the data protection helper removed" >&2
    fi
  done
}

# Helper of the Secure Enclave store (017, 018): swiftc, no profile. A new build when the source changed.
vault_build() {
  local dir="$root/build" sum
  sum="$(shasum -a 256 "$root/helper/store/main.swift" | cut -d' ' -f1)"
  # A signature that fails verification (a revoked certificate, 020) means a new build too.
  if [ -x "$dir/secret-vault" ] && [ "$(cat "$dir/secret-vault.src-sha256" 2>/dev/null)" = "$sum" ] \
      && codesign --verify --strict "$dir/secret-vault" 2>/dev/null; then
    echo "vault helper: $dir/secret-vault (up to date)" >&2
    return 0
  fi
  local rc=0
  "$dir/secret-vault" lock 2>/dev/null || true
  "$root/helper/store/build.sh" Release "$dir" >/dev/null || rc=$?
  case $rc in
    0) echo "vault helper: $dir/secret-vault" >&2 ;;
    2) echo "vault helper: not built, swiftc not found" >&2 ;;
    *) echo "vault helper: build failed" >&2; return 1 ;;
  esac
}

drop_legacy
[ $legacy_only -eq 0 ] || exit 0
src="$root/bin/secret"
dst="$HOME/.local/bin/secret"
mkdir -p "$(dirname "$dst")"
if [ -e "$dst" ] && [ ! -L "$dst" ]; then
  mv "$dst" "$dst.bak"
  echo "old file moved to $dst.bak" >&2
fi
ln -sfn "$src" "$dst"
echo "installed: $dst -> $src" >&2

# Helper: ad-hoc signature with hardened runtime. Its items are bound to the cdhash, so a new build
# gets the items from the old one before it replaces it (secret __rehelper).
helper="$root/build/secret-auth"
sum="$(shasum -a 256 "$root/helper/secret-auth.swift" | cut -d' ' -f1)"
if ! command -v swiftc >/dev/null 2>&1; then
  echo "helper: swiftc not found (xcode-select --install), Touch ID is not available" >&2
elif [ -x "$helper" ] && [ "$(cat "$helper.src-sha256" 2>/dev/null)" = "$sum" ]; then
  echo "helper: $helper (up to date)" >&2
else
  mkdir -p "$root/build"
  if swiftc -swift-version 5 -O "$root/helper/secret-auth.swift" -o "$helper.new" 2>/dev/null \
      && codesign -f -s - -o runtime "$helper.new" 2>/dev/null; then
    if [ -x "$helper" ]; then
      "$root/bin/secret" __rehelper "$helper.new" || { echo "helper: kept the old build, $helper.new is not installed" >&2; exit 1; }
    fi
    mv "$helper.new" "$helper"
    echo "$sum" > "$helper.src-sha256"
    echo "helper: $helper" >&2
  else
    rm -f "$helper.new"
    echo "helper: build failed, Touch ID is not available" >&2
  fi
fi

comp_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/completions"
if [ -d "$(dirname "$comp_dir")" ]; then
  mkdir -p "$comp_dir"
  ln -sfn "$root/completions/_secret" "$comp_dir/_secret"
  echo "zsh completion: $comp_dir/_secret (open a new terminal)" >&2
else
  echo "zsh completion: add $root/completions to fpath before compinit in ~/.zshrc" >&2
fi

vault_build || true

# SecretBar (012, 014): приложение в строке меню, profile ему не нужен. Ставится в /Applications:
# App Intents и Spotlight работают с приложениями оттуда. С --app ставится; если уже стоит,
# обновляется при каждом install.sh. Старая копия из ~/Applications удаляется.
dest="/Applications/SecretBar.app"
[ -w /Applications ] || dest="$HOME/Applications/SecretBar.app"
if [ $app -eq 1 ] || [ -d "$dest" ] || [ -d "$HOME/Applications/SecretBar.app" ]; then
  [ "$dest" = "$HOME/Applications/SecretBar.app" ] || rm -rf "$HOME/Applications/SecretBar.app"
  sum="$(cat "$root"/app/SecretBar/*.swift "$root/app/SecretBar.xcodeproj/project.pbxproj" "$root"/app/SecretBar/Assets.xcassets/AppIcon.appiconset/Contents.json "$root/app/SecretBar/Localizable.xcstrings" | shasum -a 256 | cut -d' ' -f1)"
  if [ -d "$root/build/SecretBar.app" ] && [ "$(cat "$root/build/SecretBar.src-sha256" 2>/dev/null)" = "$sum" ] \
      && codesign --verify --strict "$root/build/SecretBar.app" 2>/dev/null || "$root/app/build.sh" "$root/build" >/dev/null; then
    mkdir -p "$HOME/Applications"
    pkill -x SecretBar 2>/dev/null || true
    rm -rf "$dest" && ditto "$root/build/SecretBar.app" "$dest"
    open "$dest"
    echo "app: $dest" >&2
  else
    echo "app: build failed (Xcode needed)" >&2
  fi
fi

if [ $claude_hook -eq 1 ]; then
  "$root/hooks/install-claude.sh" "$root" "${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}" "${CLAUDE_MD:-$HOME/.claude/CLAUDE.md}"
fi
