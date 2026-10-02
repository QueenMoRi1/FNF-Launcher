#!/usr/bin/env bash
# Makes a release folder, ~/Desktop/FNF Launcher vX.Y.Z/, with the commit
# message (this version's CHANGELOG.md section). Nothing is committed or uploaded.
#
# Only GREATER.LESSER versions (X.Y.0) get builds: for those it also builds the
# installer and adds it and the SteamOS .desktop file, for GitHub Releases and
# itch.io. SMALL versions (X.Y.1, X.Y.2...) are GitHub-only: just commit and tag.
#
#   bash tools/release.sh            (OUT=/some/folder to put it elsewhere)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=$(bash "$ROOT/tools/version.sh")
OUT="${OUT:-$HOME/Desktop/FNF Launcher v$VERSION}"
# This version's notes: from "## vX.Y.Z" up to the next "## v".
notes=$(awk -v v="## v$VERSION" 'index($0, v) == 1 { on = 1; next } /^## v/ { on = 0 } on' "$ROOT/CHANGELOG.md")
[ -n "$(echo "$notes" | tr -d '[:space:]')" ] || { echo "CHANGELOG.md has no '## v$VERSION' section yet." >&2; exit 1; }
mkdir -p "$OUT"
{ echo "v$VERSION"; echo; echo "$notes" | sed '/./,$!d'; } >"$OUT/COMMIT_MESSAGE_v$VERSION.txt"
if [ "${VERSION##*.}" = 0 ]; then
	bash "$ROOT/tools/build_installer.sh"
	cp "$ROOT/dist/FNF-Launcher-Installer.sh" "$ROOT/tools/Install FNF Launcher.desktop" "$OUT/"
	chmod +x "$OUT/FNF-Launcher-Installer.sh" "$OUT/Install FNF Launcher.desktop"
	echo "Release v$VERSION is in: $OUT"
	echo "Upload FNF-Launcher-Installer.sh to a GitHub Release and to itch.io."
else
	echo "v$VERSION is a SMALL version: GitHub only, no installer build."
	echo "The commit message is in: $OUT"
fi
echo "Commit with:  git add -A && git commit -F \"$OUT/COMMIT_MESSAGE_v$VERSION.txt\""
echo "Tag it with:  git tag v$VERSION"
