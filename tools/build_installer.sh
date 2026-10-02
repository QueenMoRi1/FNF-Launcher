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
	--exclude=./wiki \
	--exclude=./_demo \
	--exclude='./assets/android_icon_192.png*' \
	--exclude=./export_presets.cfg \
	--exclude=./tools/build_android.sh \
	-cf - . | tar -C "$STAGE/app" -xf -
ffmpeg -loglevel error -y -i "$ROOT/assets/orang/real_orang.png" -vf scale=256:256:flags=lanczos "$STAGE/app/icon.png"

{
	sed "s/@VERSION@/$(bash "$ROOT/tools/version.sh")/" "$ROOT/tools/installer_header.sh"
	echo "__PAYLOAD_BELOW__"
	tar -C "$STAGE" -czf - app
} >"$OUT"
chmod +x "$OUT"
echo "Built $OUT ($(du -h "$OUT" | cut -f1))"
