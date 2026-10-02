class_name Updater
extends Node
## Update notifier. Two channels (picked in Settings, asked on first launch):
##   "github"  - newest features first: any new code on GitHub's main branch;
##               updating downloads it and builds an installer on the spot.
##   "release" - stable: only new released versions (the same build that goes
##               on itch.io); updating installs that release's installer.
## The work is done by tools/update.sh, run in a background thread.

signal checked(result: Dictionary)
signal update_finished(ok: bool, log_path: String)

const REPO := "QueenMoRi1/FNF-Launcher"
const API := "https://api.github.com/repos/" + REPO
const ITCH_PAGE := "https://queenmori1.itch.io/fnf-launcher"
const CHANNEL_NAMES := {"github": "GITHUB (NEWEST FIRST)", "release": "ITCH (STABLE)", "off": "OFF"}

var _thread: Thread


static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## "v.1.4.0" / "1.4" / "v2.0.1-beta" -> [1, 4, 0]
static func parse_version(text: String) -> Array:
	var out := []
	for m in RegEx.create_from_string("\\d+").search_all(text):
		out.append(int(m.get_string()))
		if out.size() == 3:
			break
	while out.size() < 3:
		out.append(0)
	return out


static func is_newer(theirs: String, ours: String) -> bool:
	var a := parse_version(theirs)
	var b := parse_version(ours)
	for i in 3:
		if a[i] != b[i]:
			return a[i] > b[i]
	return false


## Checks for an update and emits `checked` with:
## {available, channel, title, detail, sha (github), error}
## `last_sha` is the commit the installed GitHub build came from ("" if unknown).
func check(channel: String, last_sha: String) -> void:
	var result := {"available": false, "channel": channel, "title": "", "detail": "", "sha": "", "error": ""}
	if channel == "release":
		var rel = await _get_json(API + "/releases/latest")
		if not rel is Dictionary or not rel.has("tag_name"):
			result.error = "Couldn't reach GitHub."
		elif is_newer(rel.tag_name, current_version()):
			var v := parse_version(rel.tag_name)
			result.available = true
			result.title = "v%d.%d.%d IS OUT!" % v
			result.detail = _first_lines(str(rel.get("body", "")), 6)
	elif channel == "github":
		var head = await _get_json(API + "/commits/main")
		if not head is Dictionary or not head.has("sha"):
			result.error = "Couldn't reach GitHub."
		else:
			result.sha = head.sha
			var remote := await _get_text("https://raw.githubusercontent.com/%s/%s/project.godot" % [REPO, head.sha])
			var m := RegEx.create_from_string("config/version=\"([^\"]+)\"").search(remote)
			var remote_version := m.get_string(1) if m else ""
			if last_sha == "":
				# Installed from a release: only newer versions count as updates;
				# otherwise this commit becomes the starting point.
				if remote_version != "" and is_newer(remote_version, current_version()):
					result.available = true
					result.title = "v%s ON GITHUB" % remote_version
					result.detail = _first_lines(str(head.commit.message), 4)
			elif last_sha != head.sha:
				result.available = true
				var cmp = await _get_json("%s/compare/%s...%s" % [API, last_sha, head.sha])
				var lines := []
				if cmp is Dictionary and cmp.has("commits"):
					var commits: Array = cmp.commits
					result.title = "%d NEW CHANGE%s ON GITHUB" % [commits.size(), "" if commits.size() == 1 else "S"]
					for c in commits.slice(maxi(commits.size() - 6, 0)):
						lines.push_front("• " + str(c.commit.message).split("\n")[0])
				else:
					result.title = "NEW CHANGES ON GITHUB"
					lines.append("• " + str(head.commit.message).split("\n")[0])
				result.detail = "\n".join(lines)
	checked.emit(result)


## Runs tools/update.sh in the background; emits `update_finished`.
func run_update(channel: String) -> void:
	# Run a copy: the update replaces the launcher's files, this script included.
	var script := ProjectSettings.globalize_path("user://update.sh")
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tools/update.sh"), script)
	var log_path := ProjectSettings.globalize_path("user://logs/update.log")
	DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())
	_thread = Thread.new()
	_thread.start(func():
		var code := OS.execute("bash", ["-c", 'bash "$1" "$2" >"$3" 2>&1', "_", script, channel, log_path])
		_done.call_deferred(code == 0, log_path))


func _done(ok: bool, log_path: String) -> void:
	_thread.wait_to_finish()
	update_finished.emit(ok, log_path)


func _get_json(url: String):
	var text := await _get_text(url)
	return JSON.parse_string(text) if text != "" else null


func _get_text(url: String) -> String:
	var http := HTTPRequest.new()
	http.timeout = 15
	add_child(http)
	if http.request(url, ["User-Agent: FNF-Launcher", "Accept: application/vnd.github+json"]) != OK:
		http.queue_free()
		return ""
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return ""
	return res[3].get_string_from_utf8()


static func _first_lines(text: String, count: int) -> String:
	var lines := []
	for line in text.replace("\r", "").split("\n"):
		if line.strip_edges() != "" and lines.size() < count:
			lines.append(line.strip_edges())
	return "\n".join(lines)
