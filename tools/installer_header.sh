#!/usr/bin/env bash
# FNF Launcher installer (self-extracting: the app is appended below this script).
#
#   Double-click it, or:  bash FNF-Launcher-Installer.sh       graphical installer
#   bash FNF-Launcher-Installer.sh --cli [--yes]                text-only install
#   bash FNF-Launcher-Installer.sh --uninstall
#
# Installs to ~/.local/share/fnf-launcher. Running it again updates the app and
# keeps your games, saves, Wine prefixes and settings.
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_RELEASE="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}"
GE_API="https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest"
FNF_ASSETS_REPO="https://github.com/FunkinCrew/Funkin.assets"
# The FNF art/music the launcher (and its Steam artwork) borrows. Fetched from
# FunkinCrew at install time; it isn't ours to redistribute.
FNF_ASSET_FILES=(
	fonts/vcr.ttf
	preload/images/menuBG.png
	preload/images/menuBGMagenta.png
	preload/images/menuDesat.png
	preload/images/alphabet.png
	preload/images/alphabet.xml
	preload/images/logoBumpin.png
	preload/images/logoBumpin.xml
	preload/images/gfDanceTitle.png
	preload/images/gfDanceTitle.xml
	preload/images/icons/icon-face.png
	preload/music/freakyMenu/freakyMenu.ogg
	preload/sounds/scrollMenu.ogg
	preload/sounds/confirmMenu.ogg
	preload/sounds/cancelMenu.ogg
)
SLR4_APPID=4183110

SELF="$(realpath "$0")"
SHARE="${XDG_DATA_HOME:-$HOME/.local/share}"
DATA="$SHARE/fnf-launcher"
APP="$DATA/app"
GODOT_DIR="$DATA/godot"
GODOT="$GODOT_DIR/godot"
BIN="$HOME/.local/bin/fnf-launcher"
DESKTOP="$SHARE/applications/fnf-launcher.desktop"
GAMES="$HOME/Games/FNF"

MODE=""        # gui | cli | steps (run by the GUI) | probe (asked by the GUI)
YES=0
DO_PROTON=1
DO_RUNTIME=1
DO_STEAM=1
for arg in "$@"; do
	case "$arg" in
		--gui) MODE=gui ;;
		--cli) MODE=cli ;;
		--run-steps) MODE=steps ;;
		--probe) MODE=probe ;;
		--uninstall) MODE=uninstall ;;
		-y|--yes) YES=1 ;;
		--no-proton) DO_PROTON=0 ;;
		--no-runtime) DO_RUNTIME=0 ;;
		--no-steam) DO_STEAM=0 ;;
		-h|--help) sed -n '2,9p' "$SELF" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
	esac
done
if [ -z "$MODE" ]; then
	# Double-clicked (no terminal) or run plainly: use the graphical installer
	# when a desktop session and zenity are available.
	if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v zenity >/dev/null 2>&1; then
		MODE=gui
	else
		MODE=cli
	fi
fi
# Test hooks used by the build checks.
[ "${FNF_SKIP_PROTON:-0}" = 1 ] && DO_PROTON=0
[ "${FNF_SKIP_STEAM_PROMPTS:-0}" = 1 ] && DO_RUNTIME=0 && DO_STEAM=0

# --- Output: pretty for people, "@tag text" lines for the graphical installer ---
MACHINE=0
[ "$MODE" = steps ] && MACHINE=1
say()  { if [ "$MACHINE" = 1 ]; then echo "@step $1 $2"; else printf '\n\033[1;33m==>\033[0m \033[1m%s\033[0m\n' "$2"; fi; }
ok()   { if [ "$MACHINE" = 1 ]; then echo "@ok $*"; else printf '  \033[32m✓\033[0m %s\n' "$*"; fi; }
warn() { if [ "$MACHINE" = 1 ]; then echo "@warn $*"; else printf '  \033[35m!\033[0m %s\n' "$*"; fi; }
die()  {
	if [ "$MACHINE" = 1 ]; then echo "@fail $*"; else printf '\n\033[31mError:\033[0m %s\n' "$*" >&2; fi
	[ "$MODE" = gui ] && zenity --error --title="FNF Launcher Setup" --text="$*" 2>/dev/null
	exit 1
}
ask() {
	[ "$YES" = 1 ] && return 0
	local reply
	read -r -p "  $1 [Y/n] " reply </dev/tty || return 1
	[[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

## Downloads a file. In GUI mode it reports "@progress N" while it goes.
download() {
	local url=$1 out=$2
	if [ "$MACHINE" = 1 ]; then
		local total
		total=$(curl -fsSIL "$url" | tr -d '\r' | awk 'tolower($1) == "content-length:" { n = $2 } END { print n + 0 }')
		curl -fsSL -o "$out" "$url" &
		local pid=$!
		while kill -0 "$pid" 2>/dev/null; do
			if [ "$total" -gt 0 ]; then
				echo "@progress $(( $(stat -c %s "$out" 2>/dev/null || echo 0) * 100 / total ))"
			fi
			sleep 0.5
		done
		wait "$pid"
	else
		curl -fL --progress-bar -o "$out" "$url"
	fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

find_steam() {
	STEAM=""
	local dir
	for dir in "$HOME/.local/share/Steam" "$HOME/.steam/root" "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"; do
		if [ -d "$dir/steamapps" ]; then
			STEAM="$(cd "$dir" && pwd -P)"
			return 0
		fi
	done
	return 1
}

# True if this Wine binary is built for x86-64 (ELF e_machine 0x3E).
is_x86_64() { [ -f "$1" ] && [ "$(od -An -tx2 -j18 -N2 "$1" | tr -d ' ')" = "003e" ]; }

find_ge_proton() {
	local dir
	for dir in "$STEAM"/compatibilitytools.d/*/; do
		[ -f "$dir/proton" ] || continue
		grep -q "GE-Proton" "$dir/version" 2>/dev/null || continue
		is_x86_64 "$dir/files/bin/wine" && { basename "$dir"; return 0; }
	done
	return 1
}

## Finds this launcher's Steam shortcut. Prints "<appid> <grid dir>" or nothing.
steam_shortcut() {
	python3 - "$STEAM" "$BIN" <<'PY'
import glob, os, struct, sys
steam, exe = sys.argv[1], sys.argv[2]
for vdf in sorted(glob.glob(os.path.join(steam, "userdata/*/config/shortcuts.vdf")), key=os.path.getmtime, reverse=True):
    data = open(vdf, "rb").read()
    i, entry = 0, {}
    def cstr():
        global i
        j = data.index(b"\0", i)
        s = data[i:j].decode("utf-8", "replace")
        i = j + 1
        return s
    while i < len(data):
        t = data[i]; i += 1
        if t == 0x08:
            exe_field = entry.get("exe", "").strip('"')
            if exe_field and os.path.realpath(exe_field) == os.path.realpath(exe) and "appid" in entry:
                print(entry["appid"], os.path.join(os.path.dirname(vdf), "grid"))
                sys.exit(0)
            entry = {}
            continue
        key = cstr().lower()
        if t == 0x01:
            entry[key] = cstr()
        elif t == 0x02:
            entry[key] = struct.unpack("<I", data[i:i + 4])[0]; i += 4
PY
}

# --- Uninstall ------------------------------------------------------------------
if [ "$MODE" = uninstall ]; then
	say uninstall "Uninstalling FNF Launcher"
	rm -rf "$APP" "$GODOT_DIR"
	rm -f "$BIN" "$DESKTOP"
	rmdir "$DATA" 2>/dev/null || true
	ok "Removed the app, Godot and the shortcuts."
	ok "Kept: your games ($GAMES), saves, Wine prefixes and GE-Proton."
	ok "If you added it to Steam, remove it there with right-click > Manage > Remove."
	exit 0
fi

# --- Probe: what's already there (the graphical installer shows this) ------------
if [ "$MODE" = probe ]; then
	find_steam || true
	ge=""; slr4=0; shortcut=""; running=0; pil=0
	if [ -n "$STEAM" ]; then
		ge=$(find_ge_proton || true)
		[ -x "$STEAM/steamapps/common/SteamLinuxRuntime_4/_v2-entry-point" ] && slr4=1
		shortcut=$(steam_shortcut || true)
	fi
	pgrep -x steam >/dev/null 2>&1 && running=1
	python3 -c "import PIL" 2>/dev/null && pil=1
	printf '{"steam": "%s", "ge_proton": "%s", "runtime": %s, "shortcut": "%s", "steam_running": %s, "pillow": %s, "games": "%s", "app": "%s"}\n' \
		"$STEAM" "$ge" "$slr4" "${shortcut%% *}" "$running" "$pil" "$GAMES" "$APP"
	exit 0
fi

# --- Bootstrap: app files, FNF assets, Godot (also step 1 of the text install) ---
check_system() {
	say system "Checking your system"
	[ "$(uname -m)" = "x86_64" ] || die "FNF Launcher needs an x86_64 (64-bit Intel/AMD) Linux PC."
	[ "$(id -u)" != "0" ] || die "Don't run this as root (no sudo needed)."
	local missing=() cmd
	for cmd in curl tar unzip git python3 sha512sum 7z; do
		command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
	done
	[ "${#missing[@]}" = 0 ] || die "Missing programs: ${missing[*]}. Bazzite/SteamOS usually have these already; otherwise install them with your package manager (7z is in the 'p7zip' / 'p7zip-full' package)."
	ok "All required programs are installed."
}

install_app() {
	say app "Installing the launcher"
	local line
	line=$(awk '/^__PAYLOAD_BELOW__$/ { print NR + 1; exit }' "$SELF")
	[ -n "$line" ] || die "This installer file is damaged (no payload). Download it again."
	tail -n +"$line" "$SELF" | tar -xz -C "$TMP" || die "Couldn't unpack the launcher files."
	# Keep already-downloaded FNF assets so updates don't fetch them again.
	if [ -d "$APP/assets/funkin" ]; then
		mkdir -p "$TMP/app/assets"
		cp -r "$APP/assets/funkin" "$TMP/app/assets/"
	fi
	mkdir -p "$DATA"
	rm -rf "$APP"
	mv "$TMP/app" "$APP"
	ok "Launcher files are in $APP"
}

fetch_assets() {
	local f have=1
	for f in "${FNF_ASSET_FILES[@]}"; do
		[ -f "$APP/assets/funkin/$(basename "$f")" ] || have=0
	done
	if [ "$have" = 1 ]; then
		ok "FNF menu assets already downloaded."
		return
	fi
	say assets "Downloading the FNF menu assets from FunkinCrew"
	git clone -q --depth 1 --filter=blob:none --sparse "$FNF_ASSETS_REPO" "$TMP/fnf-assets" \
		|| die "Couldn't reach GitHub to download the FNF assets."
	git -C "$TMP/fnf-assets" sparse-checkout set --no-cone "${FNF_ASSET_FILES[@]/#//}"
	mkdir -p "$APP/assets/funkin"
	for f in "${FNF_ASSET_FILES[@]}"; do
		cp "$TMP/fnf-assets/$f" "$APP/assets/funkin/" || die "FNF asset missing upstream: $f"
	done
	ok "Got ${#FNF_ASSET_FILES[@]} FNF assets."
}

install_godot() {
	if [ -x "$GODOT" ] && "$GODOT" --version 2>/dev/null | grep -q "^${GODOT_VERSION%-stable}\.stable"; then
		ok "Godot $GODOT_VERSION already installed."
		return
	fi
	say godot "Downloading Godot $GODOT_VERSION (the engine the launcher runs on)"
	download "$GODOT_RELEASE/$GODOT_ZIP" "$TMP/$GODOT_ZIP" || die "Couldn't download Godot."
	curl -fsSL -o "$TMP/SHA512-SUMS.txt" "$GODOT_RELEASE/SHA512-SUMS.txt" || die "Couldn't download Godot's checksums."
	local expected actual
	expected=$(awk -v f="$GODOT_ZIP" '$2 == f { print $1 }' "$TMP/SHA512-SUMS.txt")
	actual=$(sha512sum "$TMP/$GODOT_ZIP" | cut -d' ' -f1)
	[ -n "$expected" ] && [ "$expected" = "$actual" ] || die "Godot download failed its checksum. Try again."
	ok "Checksum verified."
	unzip -q -o "$TMP/$GODOT_ZIP" -d "$TMP/godot"
	mkdir -p "$GODOT_DIR"
	mv "$TMP/godot/${GODOT_ZIP%.zip}" "$GODOT"
	chmod +x "$GODOT"
	ok "Godot installed."
}

import_project() {
	say import "Preparing the launcher's first start"
	if "$GODOT" --headless --path "$APP" --import >/dev/null 2>&1; then
		ok "Done."
	else
		warn "Couldn't pre-import; the first start will just take a little longer."
	fi
}

# --- Steps after the bootstrap (the graphical installer runs these) ---------------
step_proton() {
	say proton "Installing GE-Proton (runs the Windows FNF games)"
	if [ -z "$STEAM" ]; then
		warn "Skipped: Steam isn't installed."
		return
	fi
	local ge
	if ge=$(find_ge_proton); then
		ok "Already installed ($ge)."
		return
	fi
	if [ "$DO_PROTON" != 1 ]; then
		warn "Skipped. Install GE-Proton later with ProtonPlus or by running this again."
		return
	fi
	local release tar_url sum_url tar_name
	release=$(curl -fsSL "$GE_API") || die "Couldn't reach GitHub for GE-Proton."
	read -r tar_url sum_url < <(python3 -c '
import json, re, sys
assets = json.load(sys.stdin)["assets"]
tar = next(a for a in assets if re.fullmatch(r"GE-Proton[\d-]+(-x86_64)?\.tar\.gz", a["name"]))
base = tar["name"][:-len(".tar.gz")]
sha = next(a for a in assets if a["name"] == base + ".sha512sum")
print(tar["browser_download_url"], sha["browser_download_url"])' <<<"$release") || die "Couldn't find the GE-Proton download."
	tar_name=$(basename "$tar_url")
	download "$tar_url" "$TMP/$tar_name" || die "GE-Proton download failed."
	curl -fsSL -o "$TMP/ge.sha512sum" "$sum_url" || die "Couldn't download GE-Proton's checksum."
	(cd "$TMP" && sha512sum -c --quiet ge.sha512sum) || die "GE-Proton failed its checksum. Try again."
	ok "Checksum verified. Unpacking..."
	mkdir -p "$STEAM/compatibilitytools.d"
	tar -xzf "$TMP/$tar_name" -C "$STEAM/compatibilitytools.d"
	rm -f "$TMP/$tar_name"
	ok "Installed ${tar_name%.tar.gz}."
}

step_runtime() {
	say runtime "Checking Steam Linux Runtime 4.0"
	if [ -z "$STEAM" ]; then
		warn "Skipped: Steam isn't installed."
	elif [ -x "$STEAM/steamapps/common/SteamLinuxRuntime_4/_v2-entry-point" ]; then
		ok "Already installed."
	elif [ "$DO_RUNTIME" = 1 ] && { [ "$MACHINE" = 1 ] || ask "Install it through Steam now?"; }; then
		xdg-open "steam://install/$SLR4_APPID" >/dev/null 2>&1 &
		ok "Asked Steam to install it. Let that download finish before playing."
	else
		warn "Needed to play. Install it later by opening steam://install/$SLR4_APPID"
	fi
}

step_shortcuts() {
	say shortcuts "Setting up folders and shortcuts"
	mkdir -p "$GAMES"
	ok "Games folder: $GAMES"
	mkdir -p "$(dirname "$BIN")"
	cat >"$BIN" <<EOF
#!/bin/sh
exec "$GODOT" --path "$APP" "\$@"
EOF
	chmod +x "$BIN"
	mkdir -p "$(dirname "$DESKTOP")"
	cat >"$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=FNF Launcher
Comment=Friday Night Funkin' mod launcher
Exec=$BIN
Icon=$APP/icon.png
Terminal=false
Categories=Game;
EOF
	command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$(dirname "$DESKTOP")" || true
	ok "Added FNF Launcher to your app menu."
}

## Adds the Steam shortcut (if needed) and gives it custom library artwork.
step_steam() {
	say steam "Adding FNF Launcher to Steam with custom artwork"
	if [ -z "$STEAM" ]; then
		warn "Skipped: Steam isn't installed."
		return
	fi
	if [ "$DO_STEAM" != 1 ] || { [ "$MACHINE" != 1 ] && ! ask "Add FNF Launcher to Steam (with custom artwork)?"; }; then
		warn "Skipped."
		return
	fi
	local found appid grid
	found=$(steam_shortcut || true)
	if [ -z "$found" ]; then
		if ! pgrep -x steam >/dev/null 2>&1; then
			warn "Steam isn't running. Start Steam and run the installer again to add it."
			return
		fi
		if command -v steamos-add-to-steam >/dev/null 2>&1; then
			steamos-add-to-steam "$DESKTOP" >/dev/null 2>&1 || true
		else
			touch /tmp/addnonsteamgamefile
			steam "steam://addnonsteamgame/$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$DESKTOP")" >/dev/null 2>&1 &
		fi
		local i
		for i in $(seq 1 20); do
			sleep 1
			found=$(steam_shortcut || true)
			[ -n "$found" ] && break
		done
		[ -n "$found" ] || { warn "Steam didn't confirm the new shortcut. Add $BIN to Steam yourself (Games > Add a Non-Steam Game)."; return; }
		ok "Added to your Steam library."
	else
		ok "Already in your Steam library."
	fi
	read -r appid grid <<<"$found"
	if ! python3 -c "import PIL" 2>/dev/null; then
		warn "Artwork skipped: needs python3-pillow."
		return
	fi
	mkdir -p "$grid"
	python3 "$APP/tools/make_steam_art.py" "$APP/assets/funkin" "$APP/assets/orang/real_orang.png" "$grid" "$appid" >/dev/null \
		&& ok "Custom covers, banner and logo added (they show up after Steam restarts)." \
		|| warn "Couldn't make the artwork."
}

finish_text() {
	say done "FNF Launcher is installed!"
	cat <<EOF

  Start it from your app menu or Steam, or run:  $BIN

  Next steps:
   1. Put FNF games in $GAMES (one folder per game),
      or press F4 in the launcher to download them.
   2. Optional, in Settings (Esc / B):
      - Discord status: paste your Discord Application ID.
      - Friends page: paste the friends server link your friend gave you.

  To uninstall:  bash "$SELF" --uninstall

EOF
}

case "$MODE" in
	cli)
		check_system
		find_steam && ok "Found Steam at $STEAM" || warn "Steam wasn't found. Games need it (for its Linux runtime); install Steam and run this again."
		install_app
		fetch_assets
		install_godot
		step_proton
		step_runtime
		step_shortcuts
		import_project
		step_steam
		finish_text
		;;
	steps)
		exec 2>&1
		find_steam || true
		step_proton
		step_runtime
		step_shortcuts
		step_steam
		echo "@done"
		;;
	gui)
		# Plain progress window while the engine for the real installer arrives.
		log="$TMP/bootstrap.log"
		( check_system && install_app && fetch_assets && install_godot && import_project ) >"$log" 2>&1 </dev/null &
		pid=$!
		(
			while kill -0 "$pid" 2>/dev/null; do
				step=$(grep -F '==>' "$log" | tail -1 | sed 's/\x1b\[[0-9;]*m//g; s/^==> //')
				echo "# ${step:-Getting the installer ready...}"
				sleep 0.5
			done
		) | zenity --progress --pulsate --auto-close --no-cancel --width=440 \
			--title="FNF Launcher Setup" --text="Getting the installer ready..." 2>/dev/null || true
		status=0
		wait "$pid" || status=$?
		[ "$status" = 0 ] || exit 1 # die() already showed the error
		rm -rf "$TMP"
		FNF_INSTALLER_SCRIPT="$SELF" exec "$GODOT" --path "$APP" res://scenes/installer.tscn -- --installer "$SELF"
		;;
esac
exit 0
