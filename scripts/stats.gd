class_name Stats
extends RefCounted
## Play history for Funkin' Wrapped: how long each mod was played (per session)
## and which jukebox songs were listened to. Kept in user://stats.json.
##   sessions: [[unix start, seconds, slug, name], ...]
##   listens: {"<year>|<title>|<game>": count}

const PATH := "user://stats.json"
## A song counts as listened to after this much of it played.
const LISTEN_SECONDS := 30.0

static var _data := {}
static var _loaded := false
static var _track_key := ""
static var _track_time := 0.0
static var _track_counted := false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var saved = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = saved if saved is Dictionary else {}
		_data.merge({"sessions": [], "listens": {}})
	return _data


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data()))


## A mod was played from `start` (unix time) for `seconds`.
static func add_session(entry: Dictionary, start: int, seconds: int) -> void:
	if seconds < 5:
		return
	data().sessions.append([start, seconds, entry.get("slug", ""), entry.get("name", "")])
	save()


## Called every frame by the menu: counts jukebox listens.
static func tick_music(delta: float, playing: bool) -> void:
	var track: Dictionary = Music.current()
	var key := "%s|%s" % [track.get("title", ""), track.get("game", "")]
	if key != _track_key:
		_track_key = key
		_track_time = 0.0
		_track_counted = false
	if not playing or _track_counted or track.get("path", "") == "": # not Freaky Menu
		return
	_track_time += delta
	if _track_time >= LISTEN_SECONDS:
		_track_counted = true
		var year: int = Time.get_date_dict_from_system().year
		var k := "%d|%s" % [year, key]
		data().listens[k] = int(data().listens.get(k, 0)) + 1
		save()


## Everything Wrapped shows for `year`.
static func year(y: int) -> Dictionary:
	var per_mod := {} # slug -> {name, seconds, sessions}
	var total := 0
	var days := {}
	var late_night := 0
	var longest := [0, ""]
	# Unix times are UTC; days and "late night" are in the player's own time zone.
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	for s in data().sessions:
		var d := Time.get_datetime_dict_from_unix_time(int(s[0]) + bias)
		if d.year != y:
			continue
		var seconds := int(s[1])
		total += seconds
		days["%d-%d" % [d.month, d.day]] = true
		if d.hour < 4:
			late_night += 1
		if seconds > longest[0]:
			longest = [seconds, str(s[3])]
		var m: Dictionary = per_mod.get(s[2], {"name": s[3], "seconds": 0, "sessions": 0})
		m.seconds += seconds
		m.sessions += 1
		m.name = s[3]
		per_mod[s[2]] = m
	var mods := per_mod.values()
	mods.sort_custom(func(a, b): return a.seconds > b.seconds)
	var songs := []
	for k in data().listens:
		var parts: PackedStringArray = k.split("|")
		if parts.size() == 3 and int(parts[0]) == y:
			songs.append({"title": parts[1], "game": parts[2], "count": int(data().listens[k])})
	songs.sort_custom(func(a, b): return a.count > b.count)
	return {"year": y, "seconds": total, "mods": mods, "songs": songs, "days": days.size(),
		"late_night": late_night, "longest": longest, "sessions": mods.reduce(func(acc, m): return acc + m.sessions, 0)}
