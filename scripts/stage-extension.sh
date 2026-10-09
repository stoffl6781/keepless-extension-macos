#!/usr/bin/env bash
# Build phase "Stage extension": copies the shipped extension files into the Safari app extension
# and adapts the manifest. Usage: stage-extension.sh <destination>
#
# Extension checkout: $KEEPLESS_EXTENSION_DIR, else the path in .extension-dir (git-ignored),
# else ../keepless-extension. EXTENSION_VERSION names the tag a Release build must be made from.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:?destination missing}"

SRC="${KEEPLESS_EXTENSION_DIR:-}"
if [ -z "$SRC" ] && [ -f "$ROOT/.extension-dir" ]; then SRC="$(tr -d '\n' < "$ROOT/.extension-dir")"; fi
SRC="${SRC:-../keepless-extension}"
case "$SRC" in /*) ;; *) SRC="$ROOT/$SRC" ;; esac
if [ ! -f "$SRC/manifest.json" ]; then
  echo "error: Keepless extension not found at $SRC (set KEEPLESS_EXTENSION_DIR or .extension-dir)" >&2
  exit 1
fi

# Release builds must come from exactly the pinned tag, so every store version is reproducible
EXPECTED="$(tr -d '[:space:]' < "$ROOT/EXTENSION_VERSION")"
ACTUAL="$(git -C "$SRC" describe --tags --exact-match 2>/dev/null || git -C "$SRC" rev-parse --short HEAD)"
DIRTY="$(git -C "$SRC" status --porcelain --untracked-files=no)"
if [ "$ACTUAL" != "$EXPECTED" ] || [ -n "$DIRTY" ]; then
  MSG="extension at $SRC is $ACTUAL${DIRTY:+ with uncommitted changes}, expected $EXPECTED"
  if [ "${CONFIGURATION:-Debug}" = "Release" ]; then echo "error: $MSG" >&2; exit 1; fi
  echo "warning: $MSG"
fi

mkdir -p "$DEST"
# Only what the extension needs at runtime; offscreen documents do not exist in Safari
rsync -a --delete \
  --exclude '.*' --exclude 'docs/' --exclude 'tests/' --exclude 'node_modules/' \
  --exclude '*.md' --exclude 'package*.json' --exclude 'offscreen.*' \
  "$SRC/" "$DEST/"

# Safari has no idle, offscreen or downloads API (the code feature-detects them); clipboardWrite
# is only requested for the offscreen clipboard clearing.
/usr/bin/python3 - "$DEST/manifest.json" <<'PY'
import json, sys
path = sys.argv[1]
manifest = json.load(open(path, encoding='utf-8'))
unsupported = {'idle', 'offscreen', 'downloads'}
manifest['permissions'] = [p for p in manifest.get('permissions', []) if p not in unsupported]
# Touch ID runs through the container app (SafariWebExtensionHandler.swift); Chrome must not ask for this
manifest['permissions'].append('nativeMessaging')
optional = [p for p in manifest.get('optional_permissions', []) if p != 'clipboardWrite']
if optional:
    manifest['optional_permissions'] = optional
else:
    manifest.pop('optional_permissions', None)
json.dump(manifest, open(path, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
PY
