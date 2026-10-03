class_name ModHealth
extends RefCounted
## Checks a mod for things that stop it from launching, in plain English.
## Each problem: {"level": "error" | "warn" | "ok", "text": String, "fix": String}
## where fix names an automatic fix ("" = none):
##   "pick_exe"   choose the most likely game .exe again
##   "case_files" add correctly-capitalised copies of files a mod asks for

const PE_X86_64 := 0x8664
const PE_I386 := 0x14C
## Files a HaxeFlixel (lime) game needs next to its .exe.
const LIME_FILES := ["lime.ndll"]


## Runs every check. `proton_dir` is the Proton the mod would launch with ("" on Windows).
static func check(path: String, entry: Dictionary, proton_dir: String) -> Array:
	var out := []
	var exe: String = entry.get("exe", "")
	if not DirAccess.dir_exists_absolute(path):
		return [{"level": "error", "text": "The mod's folder is gone: %s" % path, "fix": ""}]
	if exe == "" or not FileAccess.file_exists(exe):
		out.append({"level": "error", "text": "Its .exe is missing. The mod was moved, renamed or only half unpacked.", "fix": "pick_exe"})
	else:
		var arch := exe_arch(exe)
		if arch == "":
			out.append({"level": "error", "text": "%s isn't a Windows program (or it's damaged). Re-download the mod." % exe.get_file(), "fix": "pick_exe"})
		elif arch == "32-bit":
			out.append({"level": "ok", "text": "32-bit game: fine, just older.", "fix": ""})
		var dir := exe.get_base_dir()
		var engine := engine_of(dir, exe.get_file())
		out.append({"level": "ok", "text": "Engine: " + engine, "fix": ""})
		if engine != "Unknown" and engine != "Godot / other" and not FileAccess.file_exists(dir.path_join("lime.ndll")):
			out.append({"level": "error", "text": "lime.ndll is missing next to the .exe, so it can't start. The download is incomplete: get it again.", "fix": ""})
		if not DirAccess.dir_exists_absolute(dir.path_join("assets")) and engine != "Godot / other":
			out.append({"level": "warn", "text": "There's no assets folder next to the .exe. If the game shows a black screen, the wrong .exe may be picked.", "fix": "pick_exe"})
		var bad_case := case_mismatches(dir)
		if not bad_case.is_empty():
			out.append({"level": "warn", "text": "%d file(s) are named with different capitals than the mod asks for (e.g. %s). Windows doesn't care, Linux can." % [bad_case.size(), bad_case[0][0].get_file()], "fix": "case_files"})
	if not _writable(path):
		out.append({"level": "error", "text": "The launcher can't write to the mod's folder, so the game can't save settings there.", "fix": ""})
	if OS.get_name() != "Windows":
		if proton_dir == "" or not FileAccess.file_exists(proton_dir.path_join("proton")):
			out.append({"level": "error", "text": "The Proton this mod uses isn't installed any more. Pick another in its PROTON setting.", "fix": ""})
		elif Proton.find_runtime(proton_dir).is_empty() and Proton.find_umu() == "":
			out.append({"level": "error", "text": "The Steam Linux Runtime isn't installed. Run the FNF Launcher installer again.", "fix": ""})
		var prefix: String = entry.get("prefix", "")
		if prefix != "" and DirAccess.dir_exists_absolute(prefix) and not FileAccess.file_exists(prefix.path_join("pfx/system.reg")):
			out.append({"level": "warn", "text": "Its Wine prefix looks half-made (the first launch was interrupted?). It's rebuilt on the next launch.", "fix": ""})
	var free := _free_gb(path)
	if free >= 0.0 and free < 1.0:
		out.append({"level": "warn", "text": "Less than 1 GB of disk space left. Big mods load everything at once and can fail.", "fix": ""})
	if not out.any(func(p): return p.level != "ok"):
		out.push_front({"level": "ok", "text": "No problems found.", "fix": ""})
	return out


## "64-bit", "32-bit", or "" if it isn't a Windows program.
static func exe_arch(exe: String) -> String:
	var f := FileAccess.open(exe, FileAccess.READ)
	if f == null or f.get_length() < 0x40:
		return ""
	if f.get_16() != 0x5A4D: # "MZ"
		return ""
	f.seek(0x3C)
	var pe := f.get_32()
	if pe + 6 > f.get_length():
		return ""
	f.seek(pe)
	if f.get_32() != 0x4550: # "PE\0\0"
		return ""
	match f.get_16():
		PE_X86_64:
			return "64-bit"
		PE_I386:
			return "32-bit"
	return ""


## A rough guess from the files next to the .exe (exe = its file name).
static func engine_of(dir: String, exe := "") -> String:
	var has := func(p: String) -> bool: return FileAccess.file_exists(dir.path_join(p)) or DirAccess.dir_exists_absolute(dir.path_join(p))
	var name := exe.to_lower()
	if has.call("addons") or has.call("data/global.hx") or name.contains("codename"):
		return "Codename Engine"
	if name.contains("psych") or has.call("assets/weeks"):
		return "Psych Engine"
	if name.contains("kade") or has.call("assets/replays") or has.call("extension-webm.ndll"):
		return "Kade Engine"
	if has.call("lime.ndll"):
		return "HaxeFlixel (base game or other)"
	if has.call("data.pck") or has.call("game.pck"):
		return "Godot / other"
	return "Unknown"


## Asset files a lime game lists in manifest/*.json that only exist on disk
## with different capitals. Returns [[asked path, real path], ...].
static func case_mismatches(dir: String) -> Array:
	var out := []
	var manifest_dir := dir.path_join("manifest")
	if not DirAccess.dir_exists_absolute(manifest_dir):
		return out
	var re := RegEx.create_from_string("pathy(\\d+):")
	for m in DirAccess.get_files_at(manifest_dir):
		if not m.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(manifest_dir.path_join(m)))
		if not data is Dictionary or not data.get("assets") is String:
			continue
		var s: String = data.assets
		for hit in re.search_all(s):
			var n := int(hit.get_string(1))
			var rel := s.substr(hit.get_end(), n).uri_decode()
			if rel == "" or ".." in rel.split("/"):
				continue
			var asked := dir.path_join(rel)
			if FileAccess.file_exists(asked):
				continue
			var real := _find_ignoring_case(dir, rel)
			if real != "":
				out.append([asked, real])
		if out.size() > 200:
			break
	return out


## Adds a correctly-named copy of each mismatched file. Returns how many.
static func fix_case(dir: String) -> int:
	var count := 0
	for pair in case_mismatches(dir):
		if DirAccess.copy_absolute(pair[1], pair[0]) == OK:
			count += 1
	return count


static func _find_ignoring_case(root: String, rel: String) -> String:
	var cur := root
	for part in rel.split("/", false):
		var found := ""
		for name in Array(DirAccess.get_files_at(cur)) + Array(DirAccess.get_directories_at(cur)):
			if name.to_lower() == part.to_lower():
				found = name
				break
		if found == "":
			return ""
		cur = cur.path_join(found)
	return cur if FileAccess.file_exists(cur) else ""


static func _writable(path: String) -> bool:
	var probe := path.path_join(".fnf-launcher-write-test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


## Free space in GB on the disk holding `path`, or -1 if unknown.
static func _free_gb(path: String) -> float:
	if OS.get_name() == "Windows":
		return -1.0
	var out := []
	if OS.execute("df", ["-Pk", path], out) != 0 or out.is_empty():
		return -1.0
	var lines: PackedStringArray = str(out[0]).strip_edges().split("\n")
	if lines.size() < 2:
		return -1.0
	var cols := lines[1].split(" ", false)
	return float(cols[3]) / 1048576.0 if cols.size() > 3 else -1.0
