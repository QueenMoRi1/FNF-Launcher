#!/usr/bin/env bash
# Makes a release: builds the installer and puts it, the SteamOS .desktop file
# and the commit message (this version's CHANGELOG.md section) in
# ~/Desktop/FNF Launcher vX.Y.Z/. Nothing is committed or uploaded.
#
#   bash tools/release.sh            (OUT=/some/folder to put it elsewhere)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=$(bash "$ROOT/tools/version.sh")
OUT="${OUT:-$HOME/Desktop/FNF Launcher v$VERSION}"
# This version's notes: from "## vX.Y.Z" up to the next "## v".
notes=$(awk -v v="## v$VERSION" 'index($0, v) == 1 { on = 1; next } /^## v/ { on = 0 } on' "$ROOT/CHANGELOG.md")
[ -n "$(echo "$notes" | tr -d '[:space:]')" ] || { echo "CHANGELOG.md has no '## v$VERSION' section yet." >&2; exit 1; }
bash "$ROOT/tools/build_installer.sh"
mkdir -p "$OUT"
cp "$ROOT/dist/FNF-Launcher-Installer.sh" "$ROOT/tools/Install FNF Launcher.desktop" "$OUT/"
chmod +x "$OUT/FNF-Launcher-Installer.sh" "$OUT/Install FNF Launcher.desktop"
{ echo "v$VERSION"; echo; echo "$notes" | sed '/./,$!d'; } >"$OUT/COMMIT_MESSAGE_v$VERSION.txt"
echo "Release v$VERSION is in: $OUT"
echo "Commit with:  git add -A && git commit -F \"$OUT/COMMIT_MESSAGE_v$VERSION.txt\""
echo "Tag it with:  git tag v$VERSION"
