class_name Scores
extends RefCounted
## Reads the high scores FNF mods save for themselves. HaxeFlixel games keep
## them in .sol files (Haxe-serialized text) under AppData in the game's Wine
## prefix, in a "songScores" map like {"bopeebo-hard": 123450}.
##
## A game's total is the sum of each song's best score (its best difficulty).

## Last part of a score key that names a difficulty ("bopeebo-hard").
const DIFFICULTIES := ["easy", "normal", "hard", "harder", "hardest", "erect", "nightmare", "insane",
	"extreme", "hell", "expert", "god", "classic", "old", "encore", "remix", "fucked", "pico", "canon"]


## {"total": int, "songs": [{"title", "difficulty", "score"}] best first, "saves": int}
static func for_game(entry: Dictionary) -> Dictionary:
	var best := {} # song -> [score, difficulty]
	var saves := 0
	var prefix: String = entry.get("prefix", "")
	if prefix != "":
		for root in ["Roaming", "Local"]:
			for path in _sol_files(prefix.path_join("pfx/drive_c/users/steamuser/AppData").path_join(root), 0):
				var data = unserialize(FileAccess.get_file_as_string(path))
				if not data is Dictionary or not data.get("songScores") is Dictionary:
					continue
				saves += 1
				for key in data.songScores:
					var score = data.songScores[key]
					if not (score is int or score is float) or str(key).begins_with("week"):
						continue
					var parts := _split(str(key))
					if not best.has(parts[0]) or int(score) > best[parts[0]][0]:
						best[parts[0]] = [int(score), parts[1]]
	var songs := []
	var total := 0
	for song in best:
		total += best[song][0]
		songs.append({"title": Library._pretty(song), "difficulty": best[song][1], "score": best[song][0]})
	songs.sort_custom(func(a, b): return a.score > b.score)
	return {"total": total, "songs": songs, "saves": saves}


## "bopeebo-hard" -> ["bopeebo", "hard"]; no difficulty -> ["bopeebo", "normal"]
static func _split(key: String) -> PackedStringArray:
	var cut := key.rfind("-")
	if cut > 0 and key.substr(cut + 1).to_lower() in DIFFICULTIES:
		return PackedStringArray([key.left(cut), key.substr(cut + 1).to_lower()])
	return PackedStringArray([key, "normal"])


static func _sol_files(dir: String, depth: int) -> PackedStringArray:
	var out := PackedStringArray()
	if depth > 4 or not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.to_lower().ends_with(".sol"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if depth == 0 and d in ["Microsoft", "wine", "Godot"]:
			continue
		out.append_array(_sol_files(dir.path_join(d), depth + 1))
	return out


# --- Haxe Unserializer (the parts save files use) ----------------------------------

class _Reader:
	var text: String
	var pos := 0
	var strings: Array = []

	func _init(t: String) -> void:
		text = t

	func peek() -> String:
		return text[pos] if pos < text.length() else ""

	func number() -> String:
		var start := pos
		while pos < text.length() and "0123456789+-.eE".contains(text[pos]):
			pos += 1
		return text.substr(start, pos - start)

	func value():
		if pos >= text.length():
			push_error("end of data")
			return null
		var c := text[pos]
		pos += 1
		match c:
			"n":
				return null
			"t":
				return true
			"f":
				return false
			"z":
				return 0
			"i":
				return int(number())
			"d":
				return float(number())
			"k", "m", "p":
				return 0.0 # NaN / -inf / +inf: no use for a score
			"y":
				var colon := text.find(":", pos)
				var length := int(text.substr(pos, colon - pos))
				var s := text.substr(colon + 1, length).uri_decode()
				pos = colon + 1 + length
				strings.append(s)
				return s
			"R":
				var i := int(number())
				return strings[i] if i < strings.size() else ""
			"o", "b":
				var end := "g" if c == "o" else "h"
				var d := {}
				while peek() != end and peek() != "":
					var key = value()
					d[str(key)] = value()
				pos += 1
				return d
			"q": # IntMap: ":<int> value" pairs
				var d := {}
				while peek() == ":":
					pos += 1
					var key := int(number())
					d[key] = value()
				pos += 1
				return d
			"a", "l":
				var arr := []
				while peek() != "h" and peek() != "":
					if peek() == "u":
						pos += 1
						for i in int(number()):
							arr.append(null)
					else:
						arr.append(value())
				pos += 1
				return arr
			"c": # class instance: name, then fields like an object
				value()
				var d := {}
				while peek() != "g" and peek() != "":
					var key = value()
					d[str(key)] = value()
				pos += 1
				return d
		pos = text.length() # something we don't read: stop safely
		return null


## Haxe-serialized text -> Dictionary/Array/values, or null if unreadable.
static func unserialize(text: String):
	if text == "":
		return null
	return _Reader.new(text).value()
