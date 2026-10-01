class_name Proton
extends RefCounted
## GE-Proton detection and launching games the same way Steam does:
## Steam Linux Runtime (pressure-vessel) -> GE-Proton -> game.exe.
## Falls back to umu-run if no Steam runtime is installed.

const RELEASES_URL := "https://github.com/GloriousEggroll/proton-ge-custom/releases"
const ELF_X86_64 := 0x3E
## Used when the exact runtime GE-Proton asks for isn't installed.
const FALLBACK_RUNTIMES := ["SteamLinuxRuntime_4", "SteamLinuxRuntime_sniper"]


static func steam_roots() -> PackedStringArray:
	var home := OS.get_environment("HOME")
	var out := PackedStringArray()
	for root in [
		home.path_join(".local/share/Steam"),
		home.path_join(".steam/root"),
		home.path_join(".var/app/com.valvesoftware.Steam/data/Steam"),
	]:
		if DirAccess.dir_exists_absolute(root.path_join("steamapps")):
			out.append(root)
	return out


## Returns the newest working GE-Proton directory, or "" if none.
static func find_ge_proton() -> String:
	var best := ""
	var best_ver: Array[int] = []
	for root in steam_roots():
		var base := root.path_join("compatibilitytools.d")
		var d := DirAccess.open(base)
		if d == null:
			continue
		for sub in d.get_directories():
			var path := base.path_join(sub)
			if not FileAccess.file_exists(path.path_join("proton")) or not runs_on_this_pc(path):
				continue
			var name := version_name(path)
			if not name.begins_with("GE-Proton"):
				continue
			var ver := _version(name)
			if best == "" or _is_newer(ver, best_ver):
				best = path
				best_ver = ver
	return best


## The real build name, e.g. "GE-Proton11-7". Tools like ProtonPlus use folder
## names such as "Proton-GE Latest", so the `version` file is checked first.
static func version_name(path: String) -> String:
	var version := FileAccess.get_file_as_string(path.path_join("version")).strip_edges()
	for part in version.split(" ", false):
		if part.begins_with("GE-Proton"):
			return part
	return path.get_file()


## False for builds made for another CPU (e.g. the aarch64 GE-Proton tarball).
static func runs_on_this_pc(proton_dir: String) -> bool:
	var f := FileAccess.open(proton_dir.path_join("files/bin/wine"), FileAccess.READ)
	if f == null or f.get_length() < 20:
		return false
	f.seek(18) # ELF e_machine
	return f.get_16() == ELF_X86_64


## Finds the Steam Linux Runtime this Proton asks for in its toolmanifest.vdf.
## Returns [runtime_dir, steam_root], or [] if none is installed.
static func find_runtime(proton_dir: String) -> Array:
	var manifest := FileAccess.get_file_as_string(proton_dir.path_join("toolmanifest.vdf"))
	var m := RegEx.create_from_string("\"require_tool_appid\"\\s+\"(\\d+)\"").search(manifest)
	var wanted := m.get_string(1) if m else ""
	for root in steam_roots():
		var acf := FileAccess.get_file_as_string(root.path_join("steamapps/appmanifest_%s.acf" % wanted))
		var dir := RegEx.create_from_string("\"installdir\"\\s+\"([^\"]+)\"").search(acf)
		if dir:
			var path := root.path_join("steamapps/common").path_join(dir.get_string(1))
			if FileAccess.file_exists(path.path_join("_v2-entry-point")):
				return [path, root]
	for root in steam_roots():
		for name in FALLBACK_RUNTIMES:
			var path := root.path_join("steamapps/common").path_join(name)
			if FileAccess.file_exists(path.path_join("_v2-entry-point")):
				return [path, root]
	return []


static func find_umu() -> String:
	for dir in OS.get_environment("PATH").split(":", false):
		var path := dir.path_join("umu-run")
		if FileAccess.file_exists(path):
			return path
	return ""


static func can_launch(proton_dir: String) -> bool:
	return proton_dir != "" and (not find_runtime(proton_dir).is_empty() or find_umu() != "")


## Starts the game in its own folder with its own prefix. Returns the pid, or -1.
static func launch(exe: String, prefix: String, proton_dir: String, log_path: String) -> int:
	DirAccess.make_dir_recursive_absolute(prefix)
	DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())
	var runtime := find_runtime(proton_dir)
	if runtime.is_empty():
		var umu := 'cd "$1" && exec env WINEPREFIX="$2" PROTONPATH="$3" GAMEID=umu-default umu-run "$4" >"$5" 2>&1'
		return OS.create_process("sh", ["-c", umu, "_", exe.get_base_dir(), prefix, proton_dir, exe, log_path])
	var script := 'cd "$1" && exec env STEAM_COMPAT_DATA_PATH="$2" STEAM_COMPAT_CLIENT_INSTALL_PATH="$6" STEAM_COMPAT_INSTALL_PATH="$1" SteamAppId=0 SteamGameId=0 "$7/_v2-entry-point" --verb=waitforexitandrun -- "$3/proton" waitforexitandrun "$4" >"$5" 2>&1'
	return OS.create_process("sh", ["-c", script, "_", exe.get_base_dir(), prefix, proton_dir, exe, log_path, runtime[1], runtime[0]])


static func _version(name: String) -> Array[int]:
	var out: Array[int] = []
	for m in RegEx.create_from_string("\\d+").search_all(name):
		out.append(m.get_string().to_int())
	return out


static func _is_newer(a: Array[int], b: Array[int]) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return a[i] > b[i]
	return a.size() > b.size()
