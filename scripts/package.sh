#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(awk -F': ' '/^## Version:/ {print $2}' "$ROOT/LoadoutPilot.toc")"
OUT="$ROOT/release"
STAGE="$OUT/LoadoutPilot"
rm -rf "$OUT"
mkdir -p "$STAGE"
for f in LoadoutPilot.toc Localization.lua Data.lua Core.lua CHANGELOG.md LICENSE; do
  cp "$ROOT/$f" "$STAGE/$f"
done
cp -R "$ROOT/Media" "$STAGE/Media"
(cd "$OUT" && zip -qr "LoadoutPilot-v${VERSION}-CurseForge.zip" LoadoutPilot)
echo "$OUT/LoadoutPilot-v${VERSION}-CurseForge.zip"
