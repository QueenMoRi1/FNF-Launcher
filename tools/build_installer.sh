#!/usr/bin/env bash
# Builds dist/FNF-Launcher-Installer.sh: tools/installer_header.sh with the
# project appended as a tar.gz payload. The borrowed FNF assets and Godot's
# cache are left out (the installer fetches/rebuilds them).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist/FNF-Launcher-Installer.sh"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

bash -n "$ROOT/tools/installer_header.sh"
mkdir -p "$STAGE/app" "$ROOT/dist"
tar -C "$ROOT" \
	--exclude=./.godot \
	--exclude=./assets/funkin \
	--exclude=./dist \
	--exclude=./promo \
	-cf - . | tar -C "$STAGE/app" -xf -
ffmpeg -loglevel error -y -i "$ROOT/assets/orang/orange.webp" -vf scale=256:256 "$STAGE/app/icon.png"

{
	cat "$ROOT/tools/installer_header.sh"
	echo "__PAYLOAD_BELOW__"
	tar -C "$STAGE" -czf - app
} >"$OUT"
chmod +x "$OUT"
echo "Built $OUT ($(du -h "$OUT" | cut -f1))"
