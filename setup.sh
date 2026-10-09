#!/usr/bin/env bash
# Regenerates the Xcode project (Safari Web Extension + macOS container app) from scratch.
# Only needed when the project is lost or the converter template changed; the project is committed.
set -euo pipefail
cd "$(dirname "$0")"

# Works without `sudo xcode-select -s` when only the Command Line Tools are selected.
if [ -d /Applications/Xcode.app ] && ! xcodebuild -version >/dev/null 2>&1; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Xcode fehlt: aus dem App Store installieren." >&2
  exit 1
fi
if [ -d Keepless ]; then
  echo "Keepless/ existiert schon – zum Neu-Erzeugen erst löschen." >&2
  exit 1
fi

SRC="${KEEPLESS_EXTENSION_DIR:-$( [ -f .extension-dir ] && tr -d '\n' < .extension-dir || echo ../keepless-extension )}"
xcrun safari-web-extension-converter "$SRC" \
  --project-location . \
  --app-name Keepless \
  --bundle-identifier app.keepless.Keepless \
  --swift \
  --macos-only \
  --no-open \
  --no-prompt

/usr/bin/python3 scripts/patch-project.py Keepless/Keepless.xcodeproj/project.pbxproj
