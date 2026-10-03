class_name ModSaves
extends RefCounted
## Where a mod keeps its saves, and backups of them.
##
## HaxeFlixel mods save .sol files under AppData. On Linux every mod has its
## own Wine prefix, so that's simply the prefix's AppData. On Windows all mods
## share %APPDATA%, so the launcher learns a mod's save folders by noticing
## which .sol files changed while it was running (see learn()).
##
## Backups: <data>/backups/<slug>/<YYYY-MM-DD_HH-MM-SS>/ holding copies of the
## .sol files and backup.json ({"time", "files": [{"path", "store"}]}).

const KEEP := 10
const MAX_FILE := 50 * 1024 * 1024
const SKIP_DIRS := ["Microsoft", "wine", "Godot", "Temp", "Packages"]


## The folders a mod's saves live in.
static func roots(entry: Dictionary) -> PackedStringArray:
	if OS.get_name() == "Windows":
		return PackedStringArray(entry.get("save_dirs", []))
	var prefix: String = entry.get("prefix", "")
	if prefix == "":
		return PackedStringArray()
	var appdata := prefix.path_join("pfx/drive_c/users/steamuser/AppData")
	return PackedStringArray([appdata.path_join("Roaming"), appdata.path_join("Local")])


## Every save file of the mod.
static func sol_files(entry: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for root in roots(entry):
		out.append_array(find_sols(root, 0))
	return out


static func find_sols(dir: String, depth: int) -> PackedStringArray:
	var out := PackedStringArray()
	if depth > 5 or not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.to_lower().ends_with(".sol"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if depth == 0 and d in SKIP_DIRS:
			continue
		out.append_array(find_sols(dir.path_join(d), depth + 1))
	return out


# --- Windows: learning a mod's save folders ------------------------------------------

## %APPDATA% and %LOCALAPPDATA% (Windows only).
static func appdata_roots() -> PackedStringArray:
	var out := PackedStringArray()
	for v in ["APPDATA", "LOCALAPPDATA"]:
		var p := OS.get_environment(v).replace("\\", "/")
		if p != "":
			out.append(p)
	return out


## path -> modified time of every .sol under AppData (Windows only; before a launch).
static func snapshot() -> Dictionary:
	var out := {}
	if OS.get_name() != "Windows":
		return out
	for root in appdata_roots():
		for f in find_sols(root, 0):
			out[f] = FileAccess.get_modified_time(f)
	return out


## After the mod closed: folders with .sol files that are new or changed since
## `before` are its save folders. Returns true if the entry changed.
static func learn(entry: Dictionary, before: Dictionary) -> bool:
	if OS.get_name() != "Windows":
		return false
	var dirs: Array = entry.get("save_dirs", [])
	var changed := false
	for f in snapshot():
		if before.has(f) and before[f] == FileAccess.get_modified_time(f):
			continue
		var dir: String = f.get_base_dir()
		if not dir in dirs:
			dirs.append(dir)
			changed = true
	entry.save_dirs = dirs
	return changed


# --- Backups -----------------------------------------------------------------------

static func backups_dir(entry: Dictionary) -> String:
	return Library.prefixes_dir().get_base_dir().path_join("backups").path_join(entry.get("slug", "game"))


## Backs up the mod's saves, unless they're the same as the newest backup.
## Returns the backup's folder name, or "" if nothing was saved.
static func backup(entry: Dictionary, reason := "") -> String:
	var files := sol_files(entry)
	if files.is_empty():
		return ""
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_MD5)
	for f in files:
		hash_ctx.update(f.to_utf8_buffer())
		hash_ctx.update(FileAccess.get_file_as_bytes(f))
	var digest := hash_ctx.finish().hex_encode()
	var list := backups(entry)
	if not list.is_empty() and list[0].get("hash", "") == digest:
		return ""
	var stamp := Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	var dir := backups_dir(entry).path_join(stamp)
	DirAccess.make_dir_recursive_absolute(dir)
	var manifest := {"time": int(Time.get_unix_time_from_system()), "hash": digest, "reason": reason, "files": []}
	for i in files.size():
		var f := files[i]
		var bytes := FileAccess.get_file_as_bytes(f)
		if bytes.size() > MAX_FILE:
			continue
		var store := "%d_%s" % [i, f.get_file()]
		var out := FileAccess.open(dir.path_join(store), FileAccess.WRITE)
		if out:
			out.store_buffer(bytes)
			manifest.files.append({"path": f, "store": store})
	var mf := FileAccess.open(dir.path_join("backup.json"), FileAccess.WRITE)
	if mf:
		mf.store_string(JSON.stringify(manifest, "\t"))
		mf.close() # written before _prune reads it back
	_prune(entry)
	return stamp


## The mod's backups, newest first: [{id, time, reason, files, hash}].
static func backups(entry: Dictionary) -> Array:
	var out := []
	var root := backups_dir(entry)
	if not DirAccess.dir_exists_absolute(root):
		return out
	for d in DirAccess.get_directories_at(root):
		var mf := root.path_join(d).path_join("backup.json")
		if not FileAccess.file_exists(mf):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(mf))
		if data is Dictionary:
			data.id = d
			out.append(data)
	out.sort_custom(func(a, b): return a.time > b.time)
	return out


## Puts a backup's files back (the current saves are backed up first).
## Returns how many files were restored.
static func restore(entry: Dictionary, id: String) -> int:
	var dir := backups_dir(entry).path_join(id)
	if not FileAccess.file_exists(dir.path_join("backup.json")):
		return 0
	var data = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("backup.json")))
	if not data is Dictionary:
		return 0
	backup(entry, "before restoring")
	var count := 0
	for f in data.get("files", []):
		var src := dir.path_join(str(f.store))
		var dest := str(f.path)
		if not FileAccess.file_exists(src) or not _inside_roots(entry, dest):
			continue
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var out := FileAccess.open(dest, FileAccess.WRITE)
		if out:
			out.store_buffer(FileAccess.get_file_as_bytes(src))
			count += 1
	return count


## A backup can only write back into the mod's own save folders.
static func _inside_roots(entry: Dictionary, path: String) -> bool:
	if ".." in path.split("/"):
		return false
	for root in roots(entry):
		if path.begins_with(root.trim_suffix("/") + "/"):
			return true
	return false


static func _prune(entry: Dictionary) -> void:
	var list := backups(entry)
	for i in range(KEEP, list.size()):
		var dir := backups_dir(entry).path_join(list[i].id)
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)
