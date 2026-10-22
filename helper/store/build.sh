#!/bin/bash
# Build the store helper secret-vault (017, 018) with swiftc, no profile.
#   helper/store/build.sh Release|Test OUTDIR → OUTDIR/secret-vault[-test], <name>.src-sha256
# Release is signed by the Apple Development certificate when there is one: the signature stays
# the same between builds, so the keychain item of the store does not ask again. Exit 2: no swiftc.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
config="${1:?Release or Test}"
out="${2:?OUTDIR}"
case "$config" in
  Release) name=secret-vault; flags=() ;;
  Test) name=secret-vault-test; flags=(-D SECRET_TEST) ;;
  *) echo "build: unknown config $config" >&2; exit 64 ;;
esac
command -v swiftc >/dev/null 2>&1 || { echo "build: swiftc not found (xcode-select --install)" >&2; exit 2; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if ! swiftc -swift-version 5 -O ${flags[@]+"${flags[@]}"} "$here/main.swift" -o "$tmp/$name" 2>"$tmp/log"; then
  grep -E 'error' "$tmp/log" | head -10 >&2
  exit 1
fi
# By SHA-1: a revoked certificate stays in the keychain next to the new one with the same name,
# the name is then ambiguous, and a binary signed by the revoked one is killed (020).
id="-"
if [ "$config" = Release ]; then
  id="$(security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development/ && !/CSSMERR/ { print $2; exit }')"
  id="${id:--}"
fi
codesign -f -s "$id" -o runtime --timestamp=none -i "local.secretcli.vault" "$tmp/$name" 2>/dev/null \
  || codesign -f -s - -o runtime -i "local.secretcli.vault" "$tmp/$name"
mkdir -p "$out"
mv -f "$tmp/$name" "$out/$name.new"
mv -f "$out/$name.new" "$out/$name"
shasum -a 256 "$here/main.swift" | cut -d' ' -f1 > "$out/$name.src-sha256"
echo "$out/$name"
