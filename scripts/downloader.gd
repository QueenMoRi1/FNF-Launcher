class_name Downloader
extends Node
## Download queue. Each job: GameBanana mod page or direct link (or a local
## archive) -> download -> unpack with 7z -> move the game folder into the games
## folder -> delete the archive. Jobs run one at a time in the background.

signal changed
## source: the link the user added (kept so the game can be exported to a list).
signal installed(game_path: String, gb: Dictionary, source: String)
signal job_failed(name: String, message: String)

## First bytes of each archive format we can unpack.
const ARCHIVE_TYPES := {"zip": [0x50, 0x4B, 0x03, 0x04], "7z": [0x37, 0x7A, 0xBC, 0xAF], "rar": [0x52, 0x61, 0x72, 0x21]}
const ACTIVE_STATES := ["downloading", "unpacking"]
const FINISHED_STATES := ["done", "failed", "canceled"]

var games_dir := ""
var gamebanana: GameBanana
## [{id, name, state, progress, message, url, archive, keep, gb, files, tmp}]
## state: looking_up | choose | queued | downloading | unpacking | done | failed | canceled
var jobs: Array[Dictionary] = []

var _next_id := 1
var _active := {}
var _http: HTTPRequest
var _thread: Thread
var _last_emit := 0


## Queues a gamebanana.com/mods/<id> page or a direct https link to an archive.
func add_url(url: String) -> void:
	url = url.strip_edges()
	var id := GameBanana.id_from_url(url)
	if id < 0 and not url.begins_with("https://") and not url.begins_with("http://"):
		job_failed.emit(url, "Paste a full link (starting with https://).")
		return
	var job := _new_job(url.get_file().uri_decode().get_basename() if id < 0 else "GameBanana mod %d" % id)
	job.source = url
	if id < 0:
		job.url = url
		job.state = "queued"
		_pump()
		return
	job.state = "looking_up"
	_emit_changed(true)
	var mod: Dictionary = await gamebanana.get_mod_files(id)
	if job.state != "looking_up": # canceled meanwhile
		return
	if mod.is_empty() or mod.files.is_empty():
		_set_failed(job, "Couldn't load that GameBanana mod (offline?)." if mod.is_empty() else "That mod has no downloadable files.")
		return
	job.name = mod.name
	job.gb = mod.duplicate()
	job.gb.erase("files")
	job.gb.erase("thumb_url")
	if mod.files.size() == 1:
		job.url = mod.files[0].url
		job.state = "queued"
		_pump()
	else:
		job.files = mod.files
		job.state = "choose"
		_emit_changed(true)


## Picks which download of a multi-file GameBanana mod to install.
func choose(job_id: int, file: Dictionary) -> void:
	var job := _find(job_id)
	if job.get("state") == "choose":
		job.url = file.url
		job.files = []
		job.state = "queued"
		_pump()


## Queues an archive that's already on disk. The user's file is left in place.
func add_file(path: String) -> void:
	var job := _new_job(path.get_file().get_basename())
	job.archive = path
	job.keep = true
	job.state = "queued"
	_pump()


func cancel(job_id: int) -> void:
	var job := _find(job_id)
	if job.is_empty() or job.state in FINISHED_STATES:
		return
	if job == _active and job.state == "downloading":
		_http.cancel_request()
		_http.queue_free()
		_http = null
		_cleanup(job)
		_active = {}
	# An unpacking job is discarded when its thread finishes (see _process).
	job.state = "canceled"
	job.message = "Canceled"
	_pump()


func clear_finished() -> void:
	jobs = jobs.filter(func(j): return not j.state in FINISHED_STATES)
	_emit_changed(true)


func is_busy() -> bool:
	return jobs.any(func(j): return not j.state in FINISHED_STATES)


## One-line status for the menu, e.g. "DOWNLOADING VS WHITTY 45%  ·  2 QUEUED".
func summary() -> String:
	var parts := PackedStringArray()
	if not _active.is_empty():
		if _active.state == "unpacking":
			parts.append("UNPACKING %s" % _active.name.to_upper())
		else:
			var pct := " %d%%" % int(_active.progress * 100) if _active.progress >= 0.0 else ""
			parts.append("DOWNLOADING %s%s" % [_active.name.to_upper(), pct])
	var waiting := jobs.filter(func(j): return j.state in ["queued", "looking_up"]).size()
	if waiting > 0:
		parts.append("%d QUEUED" % waiting)
	if jobs.any(func(j): return j.state == "choose"):
		parts.append("PICK A FILE (F4)")
	return "  ·  ".join(parts)


func _new_job(name: String) -> Dictionary:
	var job := {
		"id": _next_id, "name": name, "state": "", "progress": -1.0, "message": "",
		"url": "", "archive": "", "keep": false, "gb": {}, "files": [],
	}
	_next_id += 1
	jobs.append(job)
	return job


func _find(job_id: int) -> Dictionary:
	for job in jobs:
		if job.id == job_id:
			return job
	return {}


## Starts the next queued job if nothing is running.
func _pump() -> void:
	_emit_changed(true)
	if not _active.is_empty():
		return
	for job in jobs:
		if job.state == "queued":
			_active = job
			if job.keep:
				_extract(job)
			else:
				_download(job)
			return


func _download(job: Dictionary) -> void:
	var dir := _downloads_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	job.archive = dir.path_join("download_%d.part" % job.id)
	job.state = "downloading"
	job.progress = -1.0
	_http = HTTPRequest.new()
	_http.download_file = job.archive
	_http.download_chunk_size = 262144
	add_child(_http)
	_http.request_completed.connect(_on_downloaded.bind(job))
	if _http.request(job.url, ["User-Agent: FNF-Launcher"]) != OK:
		_fail(job, "Couldn't start the download.")
	_emit_changed(true)


func _process(_delta: float) -> void:
	if _http and not _active.is_empty():
		var total := _http.get_body_size()
		var got := _http.get_downloaded_bytes()
		_active.progress = float(got) / total if total > 0 else -1.0
		_active.message = String.humanize_size(got) + (" / " + String.humanize_size(total) if total > 0 else "")
		_emit_changed(false)
	if _thread and not _thread.is_alive():
		var code: int = _thread.wait_to_finish()
		_thread = null
		var job := _active
		if job.state == "canceled":
			_cleanup(job)
			_active = {}
			_pump()
		else:
			_place(job, code)


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, job: Dictionary) -> void:
	_http.queue_free()
	_http = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail(job, "Download failed (%s)." % ("HTTP %d" % code if code > 0 else "network error"))
		return
	_extract(job)


func _extract(job: Dictionary) -> void:
	var f := FileAccess.open(job.archive, FileAccess.READ)
	var head := Array(f.get_buffer(4)) if f else []
	f = null
	var kind := ""
	for type in ARCHIVE_TYPES:
		if head == ARCHIVE_TYPES[type]:
			kind = type
	if kind == "":
		_fail(job, "That link is a web page, not a file. Download it in your browser and use INSTALL FROM FILE.")
		return
	job.state = "unpacking"
	job.progress = -1.0
	job.message = "Unpacking..."
	job.tmp = _downloads_dir().path_join("extract_%d" % job.id)
	DirAccess.make_dir_recursive_absolute(job.tmp)
	var seven_zip := find_7zip()
	if seven_zip == "":
		_fail(job, "7-Zip isn't installed, so downloads can't be unpacked. Run the FNF Launcher installer again to get it.")
		return
	_thread = Thread.new()
	_thread.start(_unpack.bind(seven_zip, job.archive, job.tmp, kind))
	_emit_changed(true)


## 7-Zip on the system, or the standalone copy the installer puts in the
## launcher's data folder (SteamOS doesn't ship 7-Zip).
static func find_7zip() -> String:
	for dir in OS.get_environment("PATH").split(":", false):
		for exe in ["7z", "7za", "7zz"]:
			if FileAccess.file_exists(dir.path_join(exe)):
				return dir.path_join(exe)
	var bundled := Library.prefixes_dir().get_base_dir().path_join("bin/7zz")
	return bundled if FileAccess.file_exists(bundled) else ""


## Runs on a worker thread so the UI keeps animating.
static func _unpack(seven_zip: String, archive: String, dest: String, kind: String) -> int:
	var code := OS.execute(seven_zip, ["x", "-y", "-o" + dest, archive])
	if code != 0 and kind == "rar":
		code = OS.execute("unrar", ["x", "-o+", "-y", archive, dest + "/"])
	return code


func _place(job: Dictionary, code: int) -> void:
	if code != 0:
		_fail(job, "Couldn't unpack the archive (7z exit code %d)." % code)
		return
	# Step into wrapper folders ("Mod.zip" -> "Mod/" -> game files).
	var root: String = job.tmp
	while true:
		var d := DirAccess.open(root)
		var dirs := Array(d.get_directories()).filter(func(n): return n != "__MACOSX")
		if d.get_files().is_empty() and dirs.size() == 1:
			root = root.path_join(dirs[0])
		else:
			break
	if Library.find_exes(root).is_empty():
		if _looks_like_engine_mod(root):
			_fail(job, "That's a mod folder for an FNF engine (like Psych Engine), not a standalone game. Pick a version that includes the game, or put it in an engine's mods/ folder.")
		else:
			_fail(job, "No game .exe inside that download.")
		return
	var dest := _unique_dest(job.name)
	if DirAccess.rename_absolute(root, dest) != OK:
		_fail(job, "Couldn't move the game into %s." % games_dir)
		return
	_cleanup(job)
	job.state = "done"
	job.progress = 1.0
	job.message = "Installed to " + dest.get_file()
	_active = {}
	installed.emit(dest, job.gb, job.get("source", ""))
	_pump()


## Engine mod folders ship FNF data (songs/images/data) but no game .exe.
static func _looks_like_engine_mod(root: String) -> bool:
	var found := 0
	for dir in _all_dirs(root, 3):
		if dir.get_file().to_lower() in ["songs", "images", "data", "music", "weeks", "characters"]:
			found += 1
	return found >= 2


static func _all_dirs(root: String, depth: int) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(root)
	if d == null or depth < 0:
		return out
	for sub in d.get_directories():
		out.append(root.path_join(sub))
		out.append_array(_all_dirs(root.path_join(sub), depth - 1))
	return out


func _fail(job: Dictionary, message: String) -> void:
	if _http:
		_http.cancel_request()
		_http.queue_free()
		_http = null
	_cleanup(job)
	if job == _active:
		_active = {}
	_set_failed(job, message)
	_pump()


func _set_failed(job: Dictionary, message: String) -> void:
	job.state = "failed"
	job.message = message
	job_failed.emit(job.name, message)
	_emit_changed(true)


## Deletes the downloaded archive (unless it was the user's own) and temp files.
func _cleanup(job: Dictionary) -> void:
	if not job.keep and job.archive != "" and FileAccess.file_exists(job.archive):
		DirAccess.remove_absolute(job.archive)
	if job.has("tmp"):
		_remove_tree(job.tmp)
	DirAccess.remove_absolute(_downloads_dir()) # only succeeds when empty


func _emit_changed(force: bool) -> void:
	if force or Time.get_ticks_msec() - _last_emit > 100:
		_last_emit = Time.get_ticks_msec()
		changed.emit()


func _downloads_dir() -> String:
	return games_dir.path_join(".downloads")


func _unique_dest(name: String) -> String:
	var clean := RegEx.create_from_string("[/\\\\:*?\"<>|]+").sub(name, " ", true)
	clean = RegEx.create_from_string("\\s+").sub(clean, " ", true).strip_edges()
	if clean == "" or clean.begins_with("."):
		clean = "Game"
	var dest := games_dir.path_join(clean)
	var n := 2
	while DirAccess.dir_exists_absolute(dest):
		dest = games_dir.path_join("%s (%d)" % [clean, n])
		n += 1
	return dest


## Recursive delete, restricted to the .downloads folder. Symlinks are removed,
## never followed.
func _remove_tree(path: String) -> void:
	if not path.begins_with(_downloads_dir() + "/"):
		return
	var d := DirAccess.open(path)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		var child := path.path_join(sub)
		if d.is_link(child):
			d.remove(sub)
		else:
			_remove_tree(child)
	DirAccess.remove_absolute(path)
