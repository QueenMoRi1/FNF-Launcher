class_name Library
extends RefCounted
## Scans the games folder, detects each game's exe, and persists user edits.

const SAVE_PATH := "user://library.json"
const MAX_DEPTH := 3
const SONG_DEPTH := 7
## Developer test charts that ship inside some mods; not worth playing.
const SKIP_SONGS := ["test", "testsong", "offsettest", "offset-test", "test-song"]
const IGNORE_PATTERNS := [
	"unins*", "vc_redist*", "*crash*", "dxsetup*", "dxwebsetup*", "lime.exe",
	"*setup*", "*installer*", "*updater*", "notification_helper*",
]

var games_dir: String
var settings := {
	"skin": "freeplay",
	"discord_enabled": false,
	"discord_client_id": "",
	"friends_server": "",
	"friends_share": true,
	"update_channel": "", # "github", "release" or "off"; "" = not asked yet
	"update_sha": "", # GitHub channel: the commit the installed build came from
}
## folder path -> {name, exe, icon_override, slug, prefix, songs, gb}
## gb is the GameBanana match: {id, name, url, art_url} or {none: true}
var games: Dictionary = {}


func _init() -> void:
	games_dir = OS.get_environment("HOME").path_join("Games/FNF")
	_load()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		games_dir = data.get("games_dir", games_dir)
		games = data.get("games", {})
		settings.merge(data.get("settings", {}), true)


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"games_dir": games_dir, "settings": settings, "games": games}, "\t"))


## Rescans games_dir. Keeps names/overrides for folders that still exist.
func scan() -> void:
	if AndroidApps.is_android():
		# On Android the "library" is the FNF apps installed on the device.
		games = AndroidApps.scan(games)
		save()
		return
	DirAccess.make_dir_recursive_absolute(games_dir)
	var found := {}
	var dir := DirAccess.open(games_dir)
	if dir:
		for sub in dir.get_directories():
			var path := games_dir.path_join(sub)
			var exes := find_exes(path)
			if exes.is_empty():
				continue
			var entry: Dictionary = games.get(path, {})
			if entry.is_empty():
				var slug := slugify(sub)
				entry = {
					"name": sub,
					"exe": "",
					"icon_override": "",
					"slug": slug,
					"prefix": prefixes_dir().path_join(slug),
				}
			if not FileAccess.file_exists(entry.exe):
				entry.exe = pick_exe(exes, sub)
			entry.songs = find_songs(path)
			found[path] = entry
	games = found
	save()


## A shareable text list of the collection: one download link per game.
func export_collection() -> String:
	var lines := PackedStringArray([
		"# FNF Launcher game collection (%s)" % Time.get_date_string_from_system(),
		"# One download link per line. Lines starting with # are ignored.",
		"# To install everything: FNF Launcher > Downloads (F4) > IMPORT LIST...",
		"",
	])
	var missing := PackedStringArray()
	var paths := games.keys()
	paths.sort_custom(func(a, b): return games[a].name.naturalnocasecmp_to(games[b].name) < 0)
	for path in paths:
		var url := download_link(games[path])
		if url != "":
			lines.append("%s   # %s" % [url, games[path].name])
		else:
			missing.append("# %s (no download link known: set its GameBanana page with F2)" % games[path].name)
	if not missing.is_empty():
		lines.append("")
		lines.append("# Not included:")
		lines.append_array(missing)
	return "\n".join(lines) + "\n"


## The link this game can be downloaded from: its GameBanana page, or the
## direct link it was installed from.
static func download_link(entry: Dictionary) -> String:
	var gb_url: String = entry.get("gb", {}).get("url", "")
	return gb_url if gb_url != "" else entry.get("source", "")


## Links in a collection list (anything after # on a line is a comment).
static func parse_collection(text: String) -> PackedStringArray:
	var urls := PackedStringArray()
	for line in text.split("\n"):
		var url := line.get_slice("#", 0).strip_edges()
		if (url.begins_with("https://") or url.begins_with("http://")) and not url in urls:
			urls.append(url)
	return urls


## Every instrumental from every game, as [{title, game, path}]. Engine-based
## mods often ship the same base-game songs, so identical files play only once.
func all_songs() -> Array:
	var out := []
	var seen := {}
	for path in games:
		var entry: Dictionary = games[path]
		for song in entry.get("songs", []):
			var size: int = -1 if song.path.begins_with(AndroidApps.APK_SCHEME) else _file_size(song.path)
			var key := "%s|%s" % [song.title.to_lower(), size if size >= 0 else song.path]
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"title": song.title, "game": entry.name, "path": song.path})
	return out


## Finds Inst*.ogg / Inst*.mp3 files. Files with identical sizes are treated as
## duplicates (mods often ship the same Inst twice); the shorter title is kept.
static func find_songs(root: String) -> Array:
	var by_size := {}
	_collect_songs(root, 0, by_size)
	var out := by_size.values()
	# Same title, different audio: tag nested ones with their parent folder.
	var counts := {}
	for song in out:
		counts[song.title] = counts.get(song.title, 0) + 1
	for song in out:
		var parent: String = song.path.get_base_dir().get_base_dir().get_file()
		if counts[song.title] > 1 and parent.to_lower() != "songs":
			song.title += " (%s)" % _pretty(parent)
	out.sort_custom(func(a, b): return a.title.naturalnocasecmp_to(b.title) < 0)
	return out


static func _collect_songs(dir_path: String, depth: int, by_size: Dictionary) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for f in d.get_files():
		var base := f.get_basename().to_lower()
		var ext := f.get_extension().to_lower()
		if not ext in ["ogg", "mp3"] or not (base == "inst" or base.begins_with("inst-") or base.begins_with("inst_")):
			continue
		var path := dir_path.path_join(f)
		var folder := dir_path.get_file().to_lower()
		if folder in SKIP_SONGS or (folder == "song" and dir_path.get_base_dir().get_file().to_lower() in SKIP_SONGS):
			continue
		var size := _file_size(path)
		var title := song_title(path)
		if not by_size.has(size) or title.length() < by_size[size].title.length():
			by_size[size] = {"title": title, "path": path}
	if depth < SONG_DEPTH:
		for sub in d.get_directories():
			_collect_songs(dir_path.path_join(sub), depth + 1, by_size)


## "assets/songs/its-complicated/Inst-erect.ogg" -> "Its Complicated (Erect)".
## Codename keeps songs in songs/<name>/song/, so "song" folders are skipped.
static func song_title(path: String) -> String:
	var folder := path.get_base_dir()
	if folder.get_file().to_lower() == "song":
		folder = folder.get_base_dir()
	var title := _pretty(folder.get_file())
	var variant := path.get_file().get_basename().substr(4).lstrip("-_")
	if variant != "":
		title += " (%s)" % _pretty(variant)
	return title


static func _pretty(text: String) -> String:
	var words := PackedStringArray()
	for word in text.replace("-", " ").replace("_", " ").split(" ", false):
		words.append(word.left(1).to_upper() + word.substr(1))
	return " ".join(words)


static func prefixes_dir() -> String:
	var data_home := OS.get_environment("XDG_DATA_HOME")
	if data_home == "":
		data_home = OS.get_environment("HOME").path_join(".local/share")
	return data_home.path_join("fnf-launcher/prefixes")


static func slugify(text: String) -> String:
	var re := RegEx.create_from_string("[^a-z0-9]+")
	var slug := re.sub(text.to_lower(), "-", true).strip_edges().trim_prefix("-").trim_suffix("-")
	return slug if slug != "" else "game"


static func find_exes(root: String, include_ignored := false, depth := 0) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(root)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension().to_lower() == "exe" and (include_ignored or not _ignored(f)):
			out.append(root.path_join(f))
	if depth < MAX_DEPTH:
		for sub in d.get_directories():
			out.append_array(find_exes(root.path_join(sub), include_ignored, depth + 1))
	return out


## Prefers an exe named like the folder, then the shallowest, then the largest.
static func pick_exe(exes: PackedStringArray, folder_name: String) -> String:
	var folder := _norm(folder_name)
	var best := ""
	var best_score := -INF
	for exe in exes:
		var base := _norm(exe.get_file().get_basename())
		var score := float(_file_size(exe))
		score -= exe.count("/") * 1e10
		if base != "" and (folder.contains(base) or base.contains(folder)):
			score += 1e12
		if score > best_score:
			best_score = score
			best = exe
	return best


static func _ignored(file: String) -> bool:
	var lower := file.to_lower()
	for pattern in IGNORE_PATTERNS:
		if lower.match(pattern):
			return true
	return false


static func _norm(text: String) -> String:
	return RegEx.create_from_string("[^a-z0-9]").sub(text.to_lower(), "", true)


static func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else 0
