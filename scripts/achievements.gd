extends CanvasLayer
## Achievements (autoload "Achievements"): the list, unlocking, saving and the
## "achievement unlocked" toast. Secret ones (the easter eggs) only show a vague
## hint until they're unlocked.

signal unlocked(id: String)

const SAVE_PATH := "user://achievements.json"
const FONT := "res://assets/funkin/vcr.ttf"
const SKINS := ["freeplay", "steam", "blades"]
## Unlock sounds you can pick in Settings. Xbox 360 and PS3 are downloaded on
## first use and cached (they're Microsoft's/Sony's, so they aren't shipped);
## Steam's is loaded from your Steam install.
const SOUNDS := ["fnf", "xbox", "steam", "ps3", "newgrounds"]
const SOUND_NAMES := {"fnf": "FNF", "xbox": "XBOX 360", "steam": "STEAM", "ps3": "PS3", "newgrounds": "NEWGROUNDS"}
const SOUND_URLS := {
	# PCSX2's original achievement sound (the Xbox 360 one), before they swapped it out.
	"xbox": "https://raw.githubusercontent.com/PCSX2/pcsx2/0419de4bafb9381a4866d5c43ab95d730ddf15aa/bin/resources/sounds/achievements/unlock.wav",
	# The PS3 trophy sound, ripped from the console (from a PCSX2 pull request).
	"ps3": "https://raw.githubusercontent.com/PCSX2/pcsx2/b76245ea13f46deb4d46db4b6848a6c7c67ab3f9/bin/resources/sounds/achievements/unlock.wav",
	# The Newgrounds medal chime FNF plays when you earn a medal (FunkinCrew's assets).
	"newgrounds": "https://raw.githubusercontent.com/FunkinCrew/Funkin.assets/3793b0582786329d6dda41b8ac51395eedee23b5/preload/sounds/NGFadeIn.ogg",
}
const SOUND_CACHE := "user://achievement_sounds/%s"
const FNF_SOUND := "res://assets/funkin/confirmMenu.ogg"
const STEAM_SOUND := "steamui/sounds/deck_ui_achievement_toast.wav"
## id -> [title, description, hint shown while locked ("" = show the description)]
const LIST := {
	# Getting started
	"first_game": ["Welcome to the Stage", "Have a mod in your library.", ""],
	"add_game": ["New Challenger", "Add a new mod to your library.", ""],
	"ten_games": ["Mod Hoarder", "Have 10 mods in your library.", ""],
	"download": ["Special Delivery", "Install a mod with the download queue.", ""],
	"first_launch": ["Let's Funk", "Launch a mod.", ""],
	"night_owl": ["Friday Night Owl", "Launch a mod between midnight and 4 AM.", ""],
	"edit": ["Make It Yours", "Edit a mod's details.", ""],
	# Features
	"charts": ["Sheet Music", "Open the chart viewer.", ""],
	"full_song": ["Encore", "Listen to a whole song in the chart viewer.", ""],
	"dj": ["Disc Jockey", "Skip 10 jukebox tracks in one sitting.", ""],
	"skins": ["Fashionista", "Try every skin.", ""],
	"leaderboard": ["Keeping Score", "Check the leaderboard.", ""],
	"million": ["Millionaire", "Reach a total score of 1,000,000 in one mod.", ""],
	"friends": ["Social Butterfly", "Open the friends page.", ""],
	"share": ["Sharing Is Caring", "Export a collection.", ""],
	"theme": ["Interior Designer", "Open the theme editor.", ""],
	"keybinds": ["Muscle Memory", "Turn on the same keybinds for every mod.", ""],
	"restore": ["Time Traveller", "Restore a save backup.", ""],
	"health": ["Check-Up", "Run a mod health check.", ""],
	"mod_update": ["Patch Notes", "Update a mod from GameBanana.", ""],
	"wrapped": ["That's a Wrap", "Open Funkin' Wrapped.", ""],
	"gallery": ["Window Shopping", "Install a theme from the gallery.", ""],
	# Easter eggs (secret)
	"fafa": ["You Were Warned", "Typed the forbidden word.", "Some words should never be typed."],
	"deltarune": ["Dark World", "Called out a certain RPG by name.", "A darker world is waiting to be named."],
	"gooseworx": ["Tissues Recommended", "Watched the sad cartoon.", "Name the creator of a very sad cartoon."],
	"jim": ["Bin Resident", "Met Jim.", "Somebody lives somewhere smelly."],
	"jim_loud": ["INDOOR VOICE", "Said his name LOUDLY.", "Some names sound better in capitals."],
	"compost": ["Garden Waste", "Said hi to Compost.", "Something in the corner is rotting... and talking."],
	"idle": ["Still There?", "Left the launcher alone for an hour.", "Good things come to those who wait. A long time."],
	"maybe": ["Make Up Your Mind", "Couldn't decide.", "Sometimes the answer is somewhere in between."],
	"kill": ["Chose Violence", "Picked the worst possible answer.", "There's always a worse answer."],
	"jukebox_game": ["Off the Clock", "Played along in the chart viewer.", "Hold onto the music a little longer than usual."],
	"ai": ["Behind the Scenes", "Read Joey's note about how this was made.", "Some intelligence is less natural than others."],
	"chromatics": ["Perfect Pitch", "Played Boyfriend like a piano.", "Some words are more colourful than others."],
	"fc": ["No Misses", "Full combo a song in play mode.", "Hold onto the music, then don't let go."],
	"perfect": ["Sick!! Sick!! Sick!!", "Get a PERFECT rank in play mode.", "Every single note, right on time."],
	"opponent": ["Role Reversal", "Clear a song as the opponent in play mode.", "Try the other side."],
	"speed": ["Speed Demon", "Clear a song at 1.5x speed or faster in play mode.", "Faster. FASTER."],
	"cope": ["Cope", "You're coping rn i totally owned u", "Surely this is the year. Surely."],
	# The end
	"all": ["Completionist", "Unlock every other achievement.", ""],
}

var data := {"unlocked": {}, "max_games": 0, "skins": [], "sound": "fnf"}
var _queue: Array[String] = []
var _showing := false
var _skips := 0
var _chime: AudioStreamPlayer


func _ready() -> void:
	layer = 110
	process_mode = PROCESS_MODE_ALWAYS
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)) if FileAccess.file_exists(SAVE_PATH) else null
	if saved is Dictionary:
		data.merge(saved, true)
	_chime = AudioStreamPlayer.new()
	add_child(_chime)
	_load_sound()


func is_unlocked(id: String) -> bool:
	return data.unlocked.has(id)


func is_secret(id: String) -> bool:
	return LIST[id][2] != ""


func unlocked_count() -> int:
	return data.unlocked.size()


## Unlocks `id` (once) and shows the toast.
func unlock(id: String) -> void:
	if not LIST.has(id) or is_unlocked(id):
		return
	data.unlocked[id] = int(Time.get_unix_time_from_system())
	_save()
	unlocked.emit(id)
	_queue.append(id)
	_show_next()
	if id != "all" and data.unlocked.size() >= LIST.size() - 1:
		unlock("all")


## Library size changed: first mod, a newly added mod, ten mods.
func check_library(game_count: int) -> void:
	if game_count >= 1:
		unlock("first_game")
	if game_count > int(data.max_games):
		if int(data.max_games) > 0 or game_count >= 1:
			unlock("add_game")
		data.max_games = game_count
		_save()
	if game_count >= 10:
		unlock("ten_games")


func used_skin(skin: String) -> void:
	if not data.skins.has(skin):
		data.skins.append(skin)
		_save()
	for s in SKINS:
		if not data.skins.has(s):
			return
	unlock("skins")


func jukebox_skipped() -> void:
	_skips += 1
	if _skips >= 10:
		unlock("dj")


func launched_game() -> void:
	unlock("first_launch")
	if Time.get_datetime_dict_from_system().hour < 4:
		unlock("night_owl")


## Local date of an unlock, like "2026-10-01".
func date_of(id: String) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_date_string_from_unix_time(int(data.unlocked.get(id, 0)) + bias)


# --- Unlock sound -----------------------------------------------------------------

## Picks the unlock sound and plays it. `done(ok)` reports whether it's ready
## (false: couldn't download it or find Steam; the FNF sound is used instead).
func set_sound(kind: String, done := Callable()) -> void:
	if not kind in SOUNDS:
		return
	data.sound = kind
	_save()
	if SOUND_URLS.has(kind) and not FileAccess.file_exists(_cache_path(kind)):
		_download_sound(kind, done)
		return
	var ok := _load_sound()
	_chime.play()
	if done.is_valid():
		done.call(ok)


## Loads the chosen sound; falls back to the FNF one. Returns false on fallback.
func _load_sound() -> bool:
	var kind: String = data.get("sound", "fnf")
	var stream: AudioStream = null
	match kind:
		"steam":
			for root in Proton.steam_roots():
				var path: String = root.path_join(STEAM_SOUND)
				if FileAccess.file_exists(path):
					stream = AudioStreamWAV.load_from_file(path)
					break
		"xbox", "ps3", "newgrounds":
			var path := ProjectSettings.globalize_path(_cache_path(kind))
			if FileAccess.file_exists(path):
				stream = AudioStreamOggVorbis.load_from_file(path) if path.ends_with(".ogg") else AudioStreamWAV.load_from_file(path)
	var ok := stream != null or kind == "fnf"
	if stream == null:
		stream = load(FNF_SOUND)
	_chime.stream = stream
	_chime.volume_db = -4.0 if kind == "fnf" else 0.0
	return ok


## Where a downloaded sound is kept: its name plus the file's own extension.
func _cache_path(kind: String) -> String:
	return SOUND_CACHE % (kind + "." + SOUND_URLS[kind].get_extension())


func _download_sound(kind: String, done: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h, body: PackedByteArray):
		http.queue_free()
		var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 44 and body.slice(0, 4).get_string_from_ascii() in ["RIFF", "OggS"]
		if ok:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_cache_path(kind).get_base_dir()))
			var f := FileAccess.open(_cache_path(kind), FileAccess.WRITE)
			if f:
				f.store_buffer(body)
				f.close()
		if data.sound == kind:
			ok = _load_sound() and ok
			_chime.play()
		if done.is_valid():
			done.call(ok))
	if http.request(SOUND_URLS[kind]) != OK:
		http.queue_free()
		_load_sound()
		if done.is_valid():
			done.call(false)


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


# --- Toast ------------------------------------------------------------------------

func _show_next() -> void:
	if _showing or _queue.is_empty():
		return
	_showing = true
	var id: String = _queue.pop_front()
	var toast := _make_toast(LIST[id][0])
	add_child(toast)
	var view := get_viewport().get_visible_rect().size
	# Top-centre by default (clear of the hint bar, popups' buttons and the
	# jukebox); a custom theme can move it to any edge or corner.
	var where := str(CustomTheme.current.values.get("achievement position", "top")).to_lower() if CustomTheme.current else "top"
	var x := (view.x - toast.size.x) / 2.0
	if where.contains("left"):
		x = 22.0
	elif where.contains("right"):
		x = view.x - toast.size.x - 22.0
	var from_bottom := where.begins_with("bottom")
	var shown := Vector2(x, view.y - toast.size.y - 70.0 if from_bottom else 22.0)
	toast.position = shown + Vector2(0, (toast.size.y + 40.0) * (1.0 if from_bottom else -1.0))
	toast.modulate.a = 0.0
	var sound_file := CustomTheme.current.file("achievement sound") if CustomTheme.current else ""
	var theme_sound: AudioStream = CustomTheme._audio(sound_file) if sound_file != "" else null
	if theme_sound:
		var p := AudioStreamPlayer.new()
		p.stream = theme_sound
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
	else:
		_chime.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(toast, "position", shown, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(toast, "modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(1.4 if not _queue.is_empty() else 3.2) # quicker when more are waiting
	tw.chain().tween_property(toast, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func():
		toast.queue_free()
		_showing = false
		_show_next())


func _make_toast(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var t := CustomTheme.current
	style.bg_color = t.color("achievement color", Color(0.08, 0.08, 0.1, 0.94)) if t else Color(0.08, 0.08, 0.1, 0.94)
	style.set_corner_radius_all(40)
	style.set_border_width_all(3)
	style.border_color = UiKit.accent if t else Color("fdd835")
	style.content_margin_left = 14
	style.content_margin_right = 34
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(60, 60)
	badge.draw.connect(func(): draw_trophy(badge, Vector2(30, 30), 30.0, true))
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var font := load(FONT)
	for line in [["ACHIEVEMENT UNLOCKED", 16, Color("fdd835")], [title, 26, Color.WHITE]]:
		var l := Label.new()
		l.text = line[0]
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", line[1])
		l.add_theme_color_override("font_color", line[2])
		col.add_child(l)
	panel.reset_size()
	return panel


## A simple gold trophy cup in a circle (grey with a lock bar when locked).
static func draw_trophy(c: CanvasItem, center: Vector2, radius: float, lit: bool) -> void:
	var gold := Color("fdd835") if lit else Color(0.45, 0.45, 0.5)
	var dark := Color("b8860b") if lit else Color(0.3, 0.3, 0.34)
	c.draw_circle(center, radius, Color(0.16, 0.16, 0.2))
	c.draw_arc(center, radius - 1.5, 0.0, TAU, 48, gold, 3.0, true)
	var s := radius / 30.0
	var cup := PackedVector2Array([Vector2(-11, -13), Vector2(11, -13), Vector2(8, 2), Vector2(3, 6), Vector2(-3, 6), Vector2(-8, 2)])
	for i in cup.size():
		cup[i] = center + cup[i] * s
	c.draw_colored_polygon(cup, gold)
	c.draw_arc(center + Vector2(-11, -6) * s, 5.0 * s, PI / 2.0, PI * 1.5, 12, gold, 2.5 * s)
	c.draw_arc(center + Vector2(11, -6) * s, 5.0 * s, -PI / 2.0, PI / 2.0, 12, gold, 2.5 * s)
	c.draw_rect(Rect2(center + Vector2(-2, 6) * s, Vector2(4, 6) * s), gold)
	c.draw_rect(Rect2(center + Vector2(-8, 12) * s, Vector2(16, 4) * s), dark)
	if not lit:
		c.draw_line(center + Vector2(-14, 14) * s, center + Vector2(14, -14) * s, Color(0.8, 0.25, 0.25), 3.0 * s, true)
