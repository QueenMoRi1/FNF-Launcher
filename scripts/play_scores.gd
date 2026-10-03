class_name PlayScores
extends RefCounted
## Best runs in the chart viewer's play mode, in user://playmode_scores.json:
##   {"<song path>|<difficulty>|<side>|<speed>": {title, game, difficulty, side,
##    rate, score, accuracy, misses, rank, time}}

const PATH := "user://playmode_scores.json"


static func all() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	return data if data is Dictionary else {}


## Saves the run if it beats the best for the same song, difficulty, side and
## speed. Returns true if it's a new best.
static func record(song: Dictionary, difficulty: String, play: PlayMode) -> bool:
	var data := all()
	var key := "%s|%s|%d|%.1f" % [song.get("path", ""), difficulty, play.side, play.rate]
	if data.has(key) and int(data[key].score) >= play.score:
		return false
	data[key] = {"title": song.get("title", "?"), "game": song.get("game", ""), "difficulty": difficulty,
		"side": play.side, "rate": play.rate, "score": play.score, "accuracy": snappedf(play.accuracy(), 0.01),
		"misses": play.misses, "rank": play.rank(), "time": int(Time.get_unix_time_from_system())}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
	return true


## Every best run, highest score first.
static func runs() -> Array:
	var out := all().values()
	out.sort_custom(func(a, b): return int(a.score) > int(b.score))
	return out


static func best_run() -> Dictionary:
	var r := runs()
	return r[0] if not r.is_empty() else {}
