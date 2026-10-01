extends Node
## Global music (autoload "Music"): Freaky Menu during the intro, then a
## playlist of the instrumentals found in the installed games.

signal track_changed

const MENU_THEME := "res://assets/funkin/freakyMenu.ogg"
const MENU_BPM := 102.0
const VOLUME_DB := -6.0
const MENU_TRACK := {"title": "Freaky Menu", "game": "Friday Night Funkin'", "path": ""}

var player := AudioStreamPlayer.new()
## [{title, game, path}]; path "" is the menu theme
var tracks: Array = [MENU_TRACK]
var order: Array[int] = [0]
var pos := 0
var shuffle := true
var user_paused := false
var game_running := false
## Set by the intro so the menu opens with a white flash.
var intro_flash := false
var _failures := 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	player.volume_db = VOLUME_DB
	add_child(player)
	player.finished.connect(next)


func current() -> Dictionary:
	return tracks[order[pos]]


func play_menu_theme() -> void:
	var stream: AudioStreamOggVorbis = load(MENU_THEME)
	stream.loop = true
	tracks = [MENU_TRACK]
	order = [0]
	pos = 0
	player.stream = stream
	player.play()
	track_changed.emit()


## Switches to a playlist of `songs` plus the menu theme. If the menu theme is
## playing it keeps going and becomes the first track.
func start_playlist(songs: Array) -> void:
	if songs.is_empty():
		if current().path != "" or not player.playing:
			play_menu_theme()
		return
	var was_menu: bool = current().path == "" and player.playing
	tracks = [MENU_TRACK] + songs
	_build_order(0 if was_menu else -1)
	if was_menu:
		(player.stream as AudioStreamOggVorbis).loop = false
		track_changed.emit()
	else:
		_play(order[pos])


## Replaces the song list (after a rescan) without interrupting the current track.
func update_songs(songs: Array) -> void:
	if tracks.size() == 1:
		start_playlist(songs)
		return
	var playing_path: String = current().path
	tracks = [MENU_TRACK] + songs
	var idx := -1
	for i in tracks.size():
		if tracks[i].path == playing_path:
			idx = i
	if idx >= 0:
		_build_order(idx)
	else:
		_build_order(-1)
		_play(order[pos])


func next() -> void:
	pos += 1
	if pos >= order.size():
		_build_order(-1)
	_play(order[pos])


func prev() -> void:
	if player.get_playback_position() > 3.0:
		player.seek(0.0)
		return
	pos = posmod(pos - 1, order.size())
	_play(order[pos])


func toggle_pause() -> void:
	user_paused = not user_paused
	_apply_pause()


func set_shuffle(on: bool) -> void:
	shuffle = on
	_build_order(order[pos])
	track_changed.emit()


func set_game_running(on: bool) -> void:
	game_running = on
	_apply_pause()


func is_paused() -> bool:
	return player.stream_paused


func position() -> float:
	return player.get_playback_position()


func length() -> float:
	return player.stream.get_length() if player.stream else 0.0


## Briefly drops the music volume (used by the jumpscare).
func duck(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(player, "volume_db", VOLUME_DB - 24.0, 0.05)
	tw.tween_interval(seconds)
	tw.tween_property(player, "volume_db", VOLUME_DB, 0.6)


## Rebuilds the play order. `first` (a track index) is put at the front, or -1.
func _build_order(first: int) -> void:
	order.clear()
	for i in tracks.size():
		if i != first:
			order.append(i)
	if shuffle:
		order.shuffle()
	else:
		order.sort()
	if first >= 0:
		order.push_front(first)
	pos = 0


func _play(index: int) -> void:
	var track: Dictionary = tracks[index]
	var stream := _load(track.path)
	if stream == null:
		_failures += 1
		if _failures < tracks.size():
			next()
		return
	_failures = 0
	player.stream = stream
	player.play()
	_apply_pause()
	track_changed.emit()


func _apply_pause() -> void:
	player.stream_paused = user_paused or game_running


func _load(path: String) -> AudioStream:
	if path == "":
		var menu := (load(MENU_THEME) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		menu.loop = false
		return menu
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
	return null
