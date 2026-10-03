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
## A custom theme's menu music (a file path), replacing Freaky Menu. "" = none.
var menu_override := ""
## A one-off track from play_now() (not in the playlist), or empty.
var special := {}


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	player.volume_db = VOLUME_DB
	add_child(player)
	player.finished.connect(next)


func current() -> Dictionary:
	return special if not special.is_empty() else tracks[order[pos]]


func play_menu_theme() -> void:
	var stream := _menu_stream(true)
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


## Plays `track` right now without adding it to the playlist; when it ends,
## the playlist carries on with the next song.
func play_now(track: Dictionary) -> void:
	var stream := _load(track.path)
	if stream == null:
		return
	special = track
	player.stream = stream
	player.play()
	user_paused = false
	_apply_pause()
	track_changed.emit()


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
	special = {}
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


## Opens a song file (on disk, res:// or inside an APK) without playing it.
func load_stream(path: String) -> AudioStream:
	return _load(path)


func _load(path: String) -> AudioStream:
	if path == "":
		return _menu_stream(false)
	if path.begins_with("res://"):
		return load(path)
	if path.begins_with(AndroidApps.APK_SCHEME):
		# An instrumental inside an installed APK (an APK is a zip).
		var parts := AndroidApps.split_apk_path(path)
		if parts.size() != 2:
			return null
		var bytes := AndroidApps.read_from_apk(parts[0], parts[1])
		if bytes.is_empty():
			return null
		return AudioStreamOggVorbis.load_from_buffer(bytes) if parts[1].to_lower().ends_with(".ogg") else _mp3(bytes)
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
	return null


## The menu theme: Freaky Menu, or a custom theme's menu music.
func _menu_stream(looping: bool) -> AudioStream:
	if menu_override != "" and FileAccess.file_exists(menu_override):
		var custom: AudioStream = null
		match menu_override.get_extension().to_lower():
			"ogg":
				custom = AudioStreamOggVorbis.load_from_file(menu_override)
				if custom:
					custom.loop = looping
			"mp3":
				custom = AudioStreamMP3.load_from_file(menu_override)
				if custom:
					custom.loop = looping
		if custom:
			return custom
	var menu := (load(MENU_THEME) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	menu.loop = looping
	return menu


static func _mp3(bytes: PackedByteArray) -> AudioStream:
	var mp3 := AudioStreamMP3.new()
	mp3.data = bytes
	return mp3
