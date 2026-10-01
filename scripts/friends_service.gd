class_name FriendsService
extends Node
## Talks to the friends server (server/worker.js): posts what you're playing and
## fetches which of your Steam friends are online in FNF Launcher.

signal updated

const HEARTBEAT := 300.0
const POLL_FAST := 60.0
const POLL_SLOW := 180.0

var server := ""
var share := true
## Polls every minute while the Friends page is open.
var fast := false
var account := {}
var friends: Array = [] # [{id, name, avatar_url}]
var online := {} # id -> {name, playing, mod_url, art_url, ts}

var _status := {}
var _since_post := 0.0
var _since_poll := 0.0
var _busy := false


func _ready() -> void:
	account = SteamFriends.me()
	friends = SteamFriends.friends()


func configure(new_server: String, new_share: bool) -> void:
	server = new_server.strip_edges().trim_suffix("/")
	share = new_share
	online = {}
	_post()
	poll()


func is_configured() -> bool:
	return server.begins_with("https://") or server.begins_with("http://")


## playing: mod name, or "" for the menu. gb: the mod's GameBanana match, or {}.
func set_status(playing: String, gb: Dictionary) -> void:
	var status := {
		"id": account.get("id", ""),
		"name": account.get("name", ""),
		"playing": playing,
		"mod_url": gb.get("url", ""),
		"art_url": gb.get("art_url", ""),
	}
	if status != _status:
		_status = status
		_post()


func poll() -> void:
	if not is_configured() or friends.is_empty() or _busy:
		return
	_busy = true
	_since_poll = 0.0
	var ids := PackedStringArray()
	for f in friends:
		ids.append(f.id)
	var data = await _request("/status?ids=" + ",".join(ids), HTTPClient.METHOD_GET, "")
	_busy = false
	if data is Dictionary:
		online = data
		updated.emit()


func _process(delta: float) -> void:
	if not is_configured():
		return
	_since_post += delta
	_since_poll += delta
	if _since_post >= HEARTBEAT:
		_post()
	if _since_poll >= (POLL_FAST if fast else POLL_SLOW):
		poll()


func _post() -> void:
	_since_post = 0.0
	if not is_configured() or not share or _status.is_empty() or _status.id == "":
		return
	_request("/status", HTTPClient.METHOD_POST, JSON.stringify(_status))


func _request(path: String, method: HTTPClient.Method, body: String) -> Variant:
	var http := HTTPRequest.new()
	http.timeout = 10
	add_child(http)
	if http.request(server + path, ["Content-Type: application/json", "User-Agent: FNF-Launcher"], method, body) != OK:
		http.queue_free()
		return null
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return null
	return JSON.parse_string(res[3].get_string_from_utf8())
