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


## Every Proton build installed (GE-Proton, Valve's Proton, Experimental...),
## newest GE-Proton first: [{"name", "path"}]. For a mod's own PROTON setting.
static func list_all() -> Array:
	var out := []
	var seen := {}
	for root in steam_roots():
		for base in [root.path_join("compatibilitytools.d"), root.path_join("steamapps/common")]:
			for sub in DirAccess.get_directories_at(base):
				var path: String = base.path_join(sub)
				if not FileAccess.file_exists(path.path_join("proton")) or not runs_on_this_pc(path):
					continue
				var name := version_name(path)
				if seen.has(name):
					continue
				seen[name] = true
				out.append({"name": name, "path": path})
	out.sort_custom(func(a, b):
		var ga: bool = a.name.begins_with("GE-Proton")
		var gb: bool = b.name.begins_with("GE-Proton")
		if ga != gb:
			return ga
		return _is_newer(_version(a.name), _version(b.name)) if ga else a.name.naturalnocasecmp_to(b.name) < 0)
	return out


## "VAR=value OTHER=1" -> ["VAR=value", "OTHER=1"] (bad names are dropped).
static func parse_env(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var name_re := RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$")
	for part in split_args(text):
		var eq := part.find("=")
		if eq > 0 and name_re.search(part.left(eq)):
			out.append(part)
	return out


static func find_gamescope() -> String:
	for dir in OS.get_environment("PATH").split(":", false):
		if FileAccess.file_exists(dir.path_join("gamescope")):
			return dir.path_join("gamescope")
	return ""


## True when the launcher itself already runs inside gamescope (Steam's Game Mode).
static func in_gamescope() -> bool:
	return OS.get_environment("GAMESCOPE_WAYLAND_DISPLAY") != ""


## Starts the game in its own folder with its own prefix. Returns the pid, or -1.
## opts (a mod's own settings): {"env": "VAR=1 ...", "gamescope": bool,
## "fullscreen": bool, "fps": int}. gamescope is skipped inside Game Mode,
## which is gamescope already.
static func launch(exe: String, prefix: String, proton_dir: String, log_path: String, args := PackedStringArray(), opts := {}) -> int:
	DirAccess.make_dir_recursive_absolute(prefix)
	DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())
	var cmd := PackedStringArray(["env"])
	var runtime := find_runtime(proton_dir)
	if runtime.is_empty():
		cmd.append_array(["WINEPREFIX=" + prefix, "PROTONPATH=" + proton_dir, "GAMEID=umu-default"])
	else:
		cmd.append_array(["STEAM_COMPAT_DATA_PATH=" + prefix, "STEAM_COMPAT_CLIENT_INSTALL_PATH=" + runtime[1],
			"STEAM_COMPAT_INSTALL_PATH=" + exe.get_base_dir(), "SteamAppId=0", "SteamGameId=0"])
	cmd.append_array(parse_env(opts.get("env", "")))
	var gamescope := find_gamescope()
	if opts.get("gamescope", false) and gamescope != "" and not in_gamescope():
		cmd.append(gamescope)
		if opts.get("fullscreen", false):
			cmd.append("-f")
		if int(opts.get("fps", 0)) > 0:
			cmd.append_array(["-r", str(int(opts.fps))])
		cmd.append("--")
	if runtime.is_empty():
		cmd.append_array(["umu-run", exe])
	else:
		cmd.append_array([runtime[0].path_join("_v2-entry-point"), "--verb=waitforexitandrun", "--",
			proton_dir.path_join("proton"), "waitforexitandrun", exe])
	cmd.append_array(args)
	# The command is passed as arguments (never pasted into the script), so
	# names with spaces or quotes can't break it.
	var script := 'd="$1"; l="$2"; shift 2; cd "$d" && exec "$@" >"$l" 2>&1'
	return OS.create_process("sh", ["-c", script, "_", exe.get_base_dir(), log_path] + Array(cmd))


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


## '-fullscreen --name "My Name" VAR="a b"' -> ["-fullscreen", "--name", "My Name", "VAR=a b"]
## (quotes can wrap a whole word or just part of it).
static func split_args(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for m in RegEx.create_from_string('(?:[^\\s"]+|"[^"]*")+').search_all(text):
		out.append(m.get_string().replace('"', ""))
	return out
