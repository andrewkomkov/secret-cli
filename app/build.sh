#!/bin/bash
# Build SecretBar (012, 014) with Xcode: hardened runtime, no entitlements, no profile. The
# signature: the Apple Development certificate of the owner when there is one (App Intents and
# Spotlight need it, research 014 R15), else ad-hoc.
#   app/build.sh OUTDIR
# Writes OUTDIR/SecretBar.app and OUTDIR/SecretBar.src-sha256. Exit 2: no Xcode.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="${1:?OUTDIR}"
if [ -z "${DEVELOPER_DIR:-}" ] && ! xcodebuild -version >/dev/null 2>&1 && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcodebuild -version >/dev/null 2>&1 || { echo "app: Xcode not found" >&2; exit 2; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if ! xcodebuild -project "$here/SecretBar.xcodeproj" -target SecretBar -configuration Release \
    SYMROOT="$tmp/sym" OBJROOT="$tmp/obj" >"$tmp/log" 2>&1; then
  grep -E 'error' "$tmp/log" | sort -u | head -20 >&2
  exit 1
fi
mkdir -p "$out"
rm -rf "$out/SecretBar.app.new"
cp -R "$tmp/sym/Release/SecretBar.app" "$out/SecretBar.app.new"
rm -rf "$out/SecretBar.app"
mv "$out/SecretBar.app.new" "$out/SecretBar.app"
# By SHA-1, a revoked certificate skipped (020): see helper/store/build.sh.
cert="$(security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development/ && !/CSSMERR/ { print $2; exit }')"
if [ -n "$cert" ]; then
  codesign -f -s "$cert" -o runtime --timestamp=none "$out/SecretBar.app" 2>/dev/null \
    || echo "app: Apple Development signature failed, ad-hoc kept" >&2
fi
cat "$here"/SecretBar/*.swift "$here/SecretBar.xcodeproj/project.pbxproj" "$here"/SecretBar/Assets.xcassets/AppIcon.appiconset/Contents.json | shasum -a 256 | cut -d' ' -f1 > "$out/SecretBar.src-sha256"
echo "$out/SecretBar.app"
