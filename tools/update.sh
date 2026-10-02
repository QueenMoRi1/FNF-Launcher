#!/usr/bin/env bash
# FNF Launcher self-update. The launcher runs this when you press UPDATE NOW.
#
#   bash update.sh github     download the newest code on GitHub (main), build it
#                             into an installer on the spot, and install it
#   bash update.sh release    download and install the latest release's installer
#                             (the same one that goes on itch.io)
#
# Your games, saves, Wine prefixes and settings are kept, like any update.
set -euo pipefail
REPO="QueenMoRi1/FNF-Launcher"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

case "${1:-}" in
	github)
		echo "== Downloading the newest code from GitHub"
		curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" | tar -xz -C "$TMP"
		src=$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)
		echo "== Building it"
		bash "$src/tools/build_installer.sh"
		installer="$src/dist/FNF-Launcher-Installer.sh"
		;;
	release)
		echo "== Finding the latest release"
		url=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | python3 -c '
import json, sys
for a in json.load(sys.stdin).get("assets", []):
    if a["name"] == "FNF-Launcher-Installer.sh":
        print(a["browser_download_url"]); break')
		[ -n "$url" ] || { echo "The latest release has no FNF-Launcher-Installer.sh attached." >&2; exit 1; }
		echo "== Downloading $url"
		curl -fL --retry 2 -o "$TMP/FNF-Launcher-Installer.sh" "$url"
		installer="$TMP/FNF-Launcher-Installer.sh"
		;;
	*)
		sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
		exit 1
		;;
esac

echo "== Installing"
bash "$installer" --cli --yes --no-steam
echo "== Done"
