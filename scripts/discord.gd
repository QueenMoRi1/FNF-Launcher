extends Node
## Discord Rich Presence (autoload "Discord"). Runs tools/discord_rpc.py and
## sends it activity updates as JSON lines.

const HELPER := "res://tools/discord_rpc.py"

var enabled := false
var client_id := ""
var _pipe: FileAccess
## Kept open: if this pipe closes, the helper's log writes would kill it.
var _stderr: FileAccess
var _pid := -1
var _activity := {}


func configure(on: bool, id: String) -> void:
	id = id.strip_edges()
	if on == enabled and id == client_id:
		return
	_stop()
	enabled = on
	client_id = id
	if enabled and client_id.is_valid_int():
		var info := OS.execute_with_pipe("python3", [ProjectSettings.globalize_path(HELPER), client_id], false)
		if not info.is_empty():
			_pipe = info.stdio
			_stderr = info.stderr
			_pid = info.pid
	if not _activity.is_empty():
		set_activity(_activity)


func set_activity(activity: Dictionary) -> void:
	_activity = activity
	_send({"activity": activity})


func clear() -> void:
	_activity = {}
	_send({"clear": true})


func _send(msg: Dictionary) -> void:
	if _pipe == null or not OS.is_process_running(_pid):
		return
	_pipe.store_line(JSON.stringify(msg))
	_pipe.flush()


func _stop() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pipe = null
	_stderr = null
	_pid = -1


func _exit_tree() -> void:
	_stop()
