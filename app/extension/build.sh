#!/bin/bash
# Build the Safari extension app SecretBarCookies (030) from the web extension here:
# safari-web-extension-converter makes an Xcode project, xcodebuild builds a signed .app whose
# PlugIn is the extension. Apple Development certificate when present, else ad-hoc. Exit 2: no Xcode.
#   app/extension/build.sh OUTDIR  ->  OUTDIR/SecretBarCookies.app and .src-sha256
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="${1:?OUTDIR}"
app_name="SecretBarCookies"
bundle_id="local.secretcli.SecretBarCookies"
if [ -z "${DEVELOPER_DIR:-}" ] && ! xcodebuild -version >/dev/null 2>&1 && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcodebuild -version >/dev/null 2>&1 || { echo "ext: Xcode not found" >&2; exit 2; }
xcrun --find safari-web-extension-converter >/dev/null 2>&1 || { echo "ext: safari-web-extension-converter not found" >&2; exit 2; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# The extension bundle id must be prefixed by the app bundle id, so keep them consistent.
if ! xcrun safari-web-extension-converter "$here" --macos-only --no-open --no-prompt --copy-resources \
    --swift --app-name "$app_name" --bundle-identifier "$bundle_id" \
    --project-location "$tmp/proj" >"$tmp/conv.log" 2>&1; then
  grep -iE 'error' "$tmp/conv.log" | grep -iv 'missing icons' | head -10 >&2
  exit 1
fi
proj="$tmp/proj/$app_name/$app_name.xcodeproj"
if ! xcodebuild -project "$proj" -scheme "$app_name" -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$tmp/dd" CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" >"$tmp/build.log" 2>&1; then
  grep -E 'error:' "$tmp/build.log" | sort -u | head -20 >&2
  exit 1
fi
app="$tmp/dd/Build/Products/Release/$app_name.app"
[ -d "$app" ] || { echo "ext: build produced no app" >&2; exit 1; }
# Keep xcodebuild's ad-hoc signature as is: it carries the App Sandbox entitlements the extension
# needs to register with Safari. A re-sign without --entitlements strips them and the extension
# never appears. Apple Development gives Safari extensions nothing extra: Safari still needs
# "Allow Unsigned Extensions" without Developer ID notarization, which needs a paid account.
mkdir -p "$out"
rm -rf "$out/$app_name.app.new"
cp -R "$app" "$out/$app_name.app.new"
rm -rf "$out/$app_name.app"
mv "$out/$app_name.app.new" "$out/$app_name.app"
cat "$here"/manifest.json "$here"/*.html "$here"/*.js | shasum -a 256 | cut -d' ' -f1 > "$out/$app_name.src-sha256"
echo "$out/$app_name.app"
