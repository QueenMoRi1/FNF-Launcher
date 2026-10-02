class_name Chart
extends RefCounted
## Finds and reads FNF charts for a song, given the path of its Inst file.
## Understands the classic format (base game before 0.3, Psych, Kade...), Psych
## 1.0, base game 0.3+ ("V-Slice", difficulties in one -chart.json) and Codename.
## Works on folders on disk and inside Android APKs (apk://...!entry paths).
##
## A loaded chart is {"notes": [[time_ms, side, dir, length_ms, special], ...]
## sorted by time, "bpms": [[time_ms, bpm], ...], "speed": float}.
## side 0 = opponent, 1 = player; dir 0-3 = left, down, up, right.

const DIFFICULTY_ORDER := ["easy", "normal", "hard"]
const NOT_CHARTS := ["events", "meta", "metadata", "dialogue", "dialog", "credits", "info", "config"]

static var _apk_files := {} # apk path -> PackedStringArray of entries


## [{"label": "hard", "path": file, "key": V-Slice difficulty or ""}], best first.
static func find_charts(inst_path: String) -> Array:
	var song_dir := inst_path.get_base_dir()
	if song_dir.get_file().to_lower() == "song": # Codename: songs/<song>/song/Inst.ogg
		song_dir = song_dir.get_base_dir()
	var song := song_dir.get_file()
	var base := song_dir.get_base_dir().get_base_dir() # the folder holding songs/ and data/
	var found := []
	# Codename keeps charts next to the song.
	var charts_dir := _child(song_dir, "charts")
	if charts_dir != "":
		for f in _files(charts_dir):
			if f.to_lower().ends_with(".json"):
				found.append({"label": f.get_basename(), "path": charts_dir + "/" + f, "key": ""})
	var data := _child(base, "data")
	for dir in [_child(data, song), _child(_child(data, "songs"), song)]:
		if dir == "":
			continue
		for f in _files(dir):
			var lower := f.to_lower()
			if not lower.ends_with(".json") or _not_chart(lower.get_basename()):
				continue
			var path: String = dir + "/" + f
			var name := lower.get_basename()
			if name.contains("-chart"):
				# V-Slice: every difficulty in one file (variations like -chart-erect).
				var variation := name.get_slice("-chart", 1).trim_prefix("-")
				var json = _json(path)
				if json is Dictionary and json.get("notes") is Dictionary:
					for diff in json.notes:
						found.append({"label": (variation + " " + diff).strip_edges(), "path": path, "key": diff})
				continue
			var label := name.trim_prefix(song.to_lower()).trim_prefix("-")
			found.append({"label": label if label != "" else "normal", "path": path, "key": ""})
	found.sort_custom(func(a, b): return _rank(a.label) < _rank(b.label))
	return found


## The difficulty to start on: hard if there is one (it's the fun one).
static func default_index(charts: Array) -> int:
	for i in charts.size():
		if charts[i].label == "hard":
			return i
	return charts.size() - 1 if charts.size() > 0 else -1


## Vocal tracks for an Inst file: Voices<variant>.ogg, or split ones
## (Voices-Player/-Opponent, Voices-bf/-dad...).
static func find_voices(inst_path: String) -> Array:
	var dir := inst_path.get_base_dir()
	var variant := inst_path.get_file().get_basename().substr(4).to_lower() # "Inst-erect" -> "-erect"
	var exact := []
	var split := []
	for f in _files(dir):
		var lower := f.to_lower()
		if not (lower.ends_with(".ogg") or lower.ends_with(".mp3")) or not lower.begins_with("voices"):
			continue
		var rest := lower.get_basename().substr(6)
		if rest == variant:
			exact.append(dir + "/" + f)
		elif variant == "" and rest.begins_with("-") and rest.count("-") == 1 or variant != "" and rest.begins_with(variant + "-"):
			split.append(dir + "/" + f)
	return exact if not exact.is_empty() else split.slice(0, 2)


static func load_chart(entry: Dictionary, inst_path: String) -> Dictionary:
	var json = _json(entry.path)
	if not json is Dictionary:
		return {}
	if json.has("strumLines"):
		return _codename(json, inst_path)
	if json.get("notes") is Dictionary:
		return _vslice(json, entry)
	return _classic(json)


static func _classic(json: Dictionary) -> Dictionary:
	var song: Dictionary = json.song if json.get("song") is Dictionary else json
	var psych_v1 := str(song.get("format", "")).begins_with("psych_v1")
	var bpm := _num(song.get("bpm"), 100.0, true)
	var bpms := [[0.0, bpm]]
	var notes := []
	var t := 0.0
	var sections = song.get("notes")
	for section in sections if sections is Array else []:
		if not section is Dictionary:
			continue
		var new_bpm := _num(section.get("bpm"), 0.0, true)
		if _flag(section.get("changeBPM"), false) and new_bpm > 0.0 and new_bpm != bpm:
			bpm = new_bpm
			bpms.append([t, bpm])
		var must_hit := _flag(section.get("mustHitSection"), true)
		var section_notes = section.get("sectionNotes")
		for n in section_notes if section_notes is Array else []:
			if not n is Array or n.size() < 2 or not (n[1] is float or n[1] is int) or not (n[0] is float or n[0] is int):
				continue
			var lane := int(n[1])
			if lane < 0:
				continue # Psych event
			var lane8 := lane % 8
			var player: bool
			if psych_v1:
				player = lane8 < 4
			else:
				player = (lane8 < 4) == must_hit
			var length := _num(n[2] if n.size() > 2 else 0.0, 0.0)
			notes.append([float(n[0]), 1 if player else 0, lane8 % 4, maxf(length, 0.0), lane >= 8 or (n.size() > 3 and n[3] is String and n[3] != "")])
		var beats := _num(section.get("sectionBeats"), _num(section.get("lengthInSteps"), 16.0) / 4.0)
		t += maxf(beats, 0.0) * 60000.0 / bpm
	notes.sort_custom(func(a, b): return a[0] < b[0])
	return {"notes": notes, "bpms": bpms, "speed": _num(song.get("speed"), 2.0, true)}


static func _vslice(json: Dictionary, entry: Dictionary) -> Dictionary:
	var key: String = entry.key
	var notes := []
	var list = json.notes.get(key)
	for n in list if list is Array else []:
		if not n is Dictionary or not (n.get("t") is float or n.get("t") is int):
			continue
		var d := int(_num(n.get("d"), 0.0))
		if d < 0:
			continue
		notes.append([float(n.t), 1 if d % 8 < 4 else 0, d % 4, maxf(_num(n.get("l"), 0.0), 0.0), str(n.get("k", "")) != ""])
	notes.sort_custom(func(a, b): return a[0] < b[0])
	var speeds = json.get("scrollSpeed", {})
	var speed := 2.0
	if speeds is Dictionary:
		speed = _num(speeds.get(key, speeds.get("default")), 2.0, true)
	else:
		speed = _num(speeds, 2.0, true)
	# BPM lives in <song>-metadata(-variation).json next to the chart.
	var bpms := []
	var meta = _json(entry.path.replace("-chart", "-metadata"))
	if meta is Dictionary and meta.get("timeChanges") is Array:
		for tc in meta.timeChanges:
			if tc is Dictionary and _num(tc.get("bpm"), 0.0, true) > 0.0:
				bpms.append([_num(tc.get("t"), 0.0), _num(tc.get("bpm"), 100.0, true)])
	if bpms.is_empty():
		bpms = [[0.0, 100.0]]
	return {"notes": notes, "bpms": bpms, "speed": speed}


static func _codename(json: Dictionary, inst_path: String) -> Dictionary:
	var notes := []
	var lines = json.strumLines
	for line in lines if lines is Array else []:
		if not line is Dictionary:
			continue
		var position := str(line.get("position", "dad"))
		if position == "girlfriend":
			continue
		var side := 1 if position == "boyfriend" else 0
		var list = line.get("notes")
		for n in list if list is Array else []:
			if not n is Dictionary:
				continue
			notes.append([_num(n.get("time"), 0.0), side, int(_num(n.get("id"), 0.0)) % 4, maxf(_num(n.get("sLen"), 0.0), 0.0), int(_num(n.get("type"), 0.0)) != 0])
	notes.sort_custom(func(a, b): return a[0] < b[0])
	var bpm := 100.0
	var song_dir := inst_path.get_base_dir().get_base_dir()
	var meta = _json(song_dir + "/meta.json")
	if meta is Dictionary:
		bpm = _num(meta.get("bpm"), 100.0, true)
	return {"notes": notes, "bpms": [[0.0, bpm]], "speed": _num(json.get("scrollSpeed"), 2.0, true)}


## A number from chart JSON, which isn't always clean: numbers, numeric
## strings, or `fallback`. positive=true also rejects zero and negatives.
static func _num(value, fallback: float, positive := false) -> float:
	var n := fallback
	if value is float or value is int:
		n = float(value)
	elif value is String and value.is_valid_float():
		n = value.to_float()
	if is_nan(n) or is_inf(n) or (positive and n <= 0.0):
		return fallback
	return n


## A true/false from chart JSON (some editors wrote "true"/"false" strings or 0/1).
static func _flag(value, fallback: bool) -> bool:
	if value is bool:
		return value
	if value is float or value is int:
		return value != 0
	if value is String:
		match value.to_lower():
			"true", "yes", "1":
				return true
			"false", "no", "0":
				return false
	return fallback


## Beat number at `ms`, following BPM changes.
static func beat_at(bpms: Array, ms: float) -> float:
	var beat := 0.0
	for i in bpms.size():
		var start: float = bpms[i][0]
		var end: float = bpms[i + 1][0] if i + 1 < bpms.size() else INF
		var crochet: float = 60000.0 / maxf(bpms[i][1], 1.0)
		if ms < end:
			return beat + maxf(ms - start, 0.0) / crochet
		beat += (end - start) / crochet
	return beat


static func bpm_at(bpms: Array, ms: float) -> float:
	var bpm := 100.0
	for change in bpms:
		if change[0] <= ms:
			bpm = change[1]
	return bpm


static func _rank(label: String) -> int:
	var i := DIFFICULTY_ORDER.find(label)
	return i if i >= 0 else DIFFICULTY_ORDER.size()


static func _not_chart(name: String) -> bool:
	if name.contains("dialog"):
		return true
	for word in NOT_CHARTS:
		if name == word or name.ends_with("-" + word) or name.ends_with("_" + word):
			return true
	return false


static func _json(path: String):
	var text := _read_text(path)
	if text == "":
		return null
	text = text.strip_edges()
	var json := JSON.new()
	if json.parse(text) == OK:
		return json.data
	if text.rfind("}") > 0 and json.parse(text.left(text.rfind("}") + 1)) == OK:
		return json.data # trailing junk from old chart editors
	return null


# --- Files on disk or inside an APK --------------------------------------------

static func _read_text(path: String) -> String:
	var bytes := PackedByteArray()
	if path.begins_with(AndroidApps.APK_SCHEME):
		var parts := AndroidApps.split_apk_path(path)
		if parts.size() == 2:
			bytes = AndroidApps.read_from_apk(parts[0], parts[1])
	elif FileAccess.file_exists(path):
		bytes = FileAccess.get_file_as_bytes(path)
	if bytes.has(0):
		# Some charts were saved as UTF-16 or padded with NULs; JSON is ASCII anyway.
		var clean := PackedByteArray()
		for b in bytes:
			if b != 0:
				clean.append(b)
		bytes = clean
	return bytes.get_string_from_utf8()


## Names of the files (and folders, with dirs=true) directly inside `dir`.
static func _files(dir: String, dirs := false) -> PackedStringArray:
	if dir == "":
		return PackedStringArray()
	if dir.begins_with(AndroidApps.APK_SCHEME):
		var parts := AndroidApps.split_apk_path(dir + "/")
		if parts.size() != 2:
			return PackedStringArray()
		if not _apk_files.has(parts[0]):
			_apk_files[parts[0]] = AndroidApps.list_apk(parts[0])
		var prefix := parts[1]
		var out := PackedStringArray()
		for f: String in _apk_files[parts[0]]:
			if f.begins_with(prefix):
				var rest := f.substr(prefix.length())
				var slash := rest.find("/")
				var name := rest if slash < 0 else rest.left(slash)
				if (slash >= 0) == dirs and name != "" and not out.has(name):
					out.append(name)
		return out
	return DirAccess.get_directories_at(dir) if dirs else DirAccess.get_files_at(dir)


## `parent/name` matched case-insensitively ("" if there's no such folder).
static func _child(parent: String, name: String) -> String:
	if parent == "":
		return ""
	for d in _files(parent, true):
		if d.to_lower() == name.to_lower():
			return parent + "/" + d
	return ""
