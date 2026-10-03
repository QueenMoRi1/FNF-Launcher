extends CanvasLayer
## Global cheat codes (autoload "Cheats"). Type "fafa", "deltarune",
## "gooseworx", "jim", "compost", "artificial" or "chromatics" anywhere. "JIM" in caps plays the video.

const ORANGE := "res://assets/orang/orange.webp"
const BOOM := "res://assets/orang/vine_boom.mp3"
const BLIP := "res://assets/funkin/scrollMenu.ogg"
const FONT := "res://assets/funkin/vcr.ttf"
const DELTARUNE_APPID := "1671210"
const NO_MORE_TEARS := "res://assets/orang/no_more_tears.ogv"
const COMPOST_VIDEO := "res://assets/compost/compost.ogv"
const JIM_VIDEO := "res://assets/jim/jim.ogv"
const JIM := {"title": "I'm Jim and I Live in the Bin", "game": "Caddicarus", "path": "res://assets/jim/jim.ogg"}

const AI_NOTE := """hey. real talk for a sec.

FNF Launcher was vibecoded with the help of an AI called Claude. But I (Joey) put a lot of my own effort and code into it too: the ideas, the testing, the fixing, and the orang. So please don't hate my software.

AI is a tool. It's not a replacement for creativity.

Thank you for using my software.

- Joey"""

var typed := ""
## What was typed with its original capitals (typed is lowercased).
var typed_raw := ""
var active := false


func _ready() -> void:
	layer = 100
	process_mode = PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	# Any key closes the "ai:" note once it has finished typing out.
	if has_meta("ai_note") and key and key.pressed and not key.echo:
		get_viewport().set_input_as_handled()
		_close_ai_note(get_meta("ai_note"))
		return
	if key == null or not key.pressed or key.echo or key.unicode == 0:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit or active:
		return # (while an egg is open, e.g. playing "jim" on the chromatics piano)
	typed_raw = (typed_raw + char(key.unicode)).right(32) # long enough for the longest code
	typed = typed_raw.to_lower()
	if typed.ends_with("fafa"):
		typed_raw = ""
		typed = ""
		jumpscare()
	elif typed.ends_with("deltarune"):
		typed_raw = ""
		typed = ""
		deltarune()
	elif typed.ends_with("gooseworx"):
		typed_raw = ""
		typed = ""
		gooseworx()
	elif typed.ends_with("yearofthelinuxdesktop"):
		typed_raw = ""
		typed = ""
		Achievements.unlock("cope")
	elif typed.ends_with("chromatics"):
		typed_raw = ""
		typed = ""
		chromatics()
	elif typed.ends_with("artificial"):
		typed_raw = ""
		typed = ""
		ai_note()
	elif typed.ends_with("compost"):
		typed_raw = ""
		typed = ""
		compost()
	elif typed.ends_with("jim"):
		jim(typed_raw.ends_with("JIM"))
		typed_raw = ""
		typed = ""


## Runs a code typed into a text box (Android has no keyboard to type them blind).
func run_code(text: String) -> void:
	match text.strip_edges().to_lower():
		"fafa":
			jumpscare()
		"deltarune":
			deltarune()
		"gooseworx":
			gooseworx()
		"compost":
			compost()
		"artificial":
			ai_note()
		"chromatics":
			chromatics()
		"yearofthelinuxdesktop":
			Achievements.unlock("cope")
		"jim":
			jim(text.strip_edges() == "JIM")


func jumpscare() -> void:
	if active:
		return
	active = true
	Achievements.unlock("fafa")
	var screen := get_viewport().get_visible_rect().size

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var orange := TextureRect.new()
	orange.texture = load(ORANGE)
	orange.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	orange.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(orange)
	orange.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orange.pivot_offset = screen / 2
	orange.scale = Vector2(0.3, 0.3)

	var boom := AudioStreamPlayer.new()
	boom.stream = load(BOOM)
	boom.volume_db = 6.0
	add_child(boom)
	boom.finished.connect(boom.queue_free)
	boom.play()
	Music.duck(1.3)

	var tw := create_tween()
	tw.tween_property(orange, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(orange, "scale", Vector2.ONE, 0.2)
	tw.tween_interval(1.1)
	tw.tween_property(root, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_end.bind(root))

	var shake := create_tween()
	for i in 10:
		shake.tween_property(self, "offset", Vector2(randf_range(-30, 30), randf_range(-30, 30)), 0.05)
	shake.tween_property(self, "offset", Vector2.ZERO, 0.05)


func _end(root: Control) -> void:
	root.queue_free()
	active = false


## Opens Deltarune through Steam if it's installed; otherwise Kris gets told off.
func deltarune() -> void:
	if active:
		return
	Achievements.unlock("deltarune")
	if deltarune_installed():
		_textbox("* You opened DELTARUNE.", false)
		get_tree().create_timer(1.2).timeout.connect(OS.shell_open.bind("steam://rungameid/" + DELTARUNE_APPID))
	else:
		_textbox("God Damn It Kris!", true)


static func deltarune_installed() -> bool:
	for root in Proton.steam_roots():
		var vdf := FileAccess.get_file_as_string(root.path_join("steamapps/libraryfolders.vdf"))
		var libraries := [root]
		for m in RegEx.create_from_string("\"path\"\\s+\"([^\"]+)\"").search_all(vdf):
			libraries.append(m.get_string(1))
		for lib in libraries:
			if FileAccess.file_exists(lib.path_join("steamapps/appmanifest_%s.acf" % DELTARUNE_APPID)):
				return true
	return false


## Deltarune-style textbox: black box, white border, typed out with a blip.
func _textbox(text: String, angry: bool) -> void:
	active = true
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.set_border_width_all(6)
	style.border_color = Color.WHITE
	style.set_content_margin_all(32)
	box.add_theme_stylebox_override("panel", style)
	root.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 140
	box.offset_right = -140
	box.offset_top = -250
	box.offset_bottom = -50
	var label := Label.new()
	label.text = text
	label.visible_characters = 0
	label.add_theme_font_override("font", load(FONT))
	label.add_theme_font_size_override("font_size", 52)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var blip := AudioStreamPlayer.new()
	blip.stream = load(BLIP)
	blip.pitch_scale = 1.8
	blip.volume_db = -4.0
	root.add_child(blip)

	var tw := create_tween()
	for i in text.length():
		tw.tween_callback(_type_char.bind(label, blip, i)).set_delay(0.045)
	if angry:
		for i in 8:
			tw.tween_property(self, "offset", Vector2(randf_range(-14, 14), randf_range(-10, 10)), 0.04)
		tw.tween_property(self, "offset", Vector2.ZERO, 0.04)
	tw.tween_interval(2.5)
	tw.tween_property(root, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_end.bind(root))


func _type_char(label: Label, blip: AudioStreamPlayer, i: int) -> void:
	label.visible_characters = i + 1
	if label.text[i] != " ":
		blip.play()


## Jim lives in the bin. He's on the jukebox now; SHOUT it and you get the video.
func jim(loud := false) -> void:
	if active:
		return
	Achievements.unlock("jim")
	if loud:
		Achievements.unlock("jim_loud")
		_play_video(JIM_VIDEO)
	else:
		Music.play_now(JIM)


## "ai:" - a note from Joey about how FNF Launcher was made.
func ai_note() -> void:
	if active:
		return
	active = true
	Achievements.unlock("ai")
	Music.player.stream_paused = true
	var root := ColorRect.new()
	root.color = Color.BLACK
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.modulate.a = 0.0
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = AI_NOTE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load(FONT))
	label.add_theme_font_size_override("font_size", 30)
	label.visible_characters = 0
	root.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 140
	label.offset_right = -140
	var hint := Label.new()
	hint.text = "press any key"
	hint.add_theme_font_override("font", load(FONT))
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.0
	root.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -60
	hint.offset_bottom = -30
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.6)
	tw.tween_property(label, "visible_characters", AI_NOTE.length(), AI_NOTE.length() * 0.025)
	tw.tween_property(hint, "modulate:a", 1.0, 0.5)
	tw.tween_callback(func(): root.set_meta("closable", true))
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close_ai_note(root))
	set_meta("ai_note", root)


func _close_ai_note(root: Control) -> void:
	if not root.has_meta("closable") or root.has_meta("closing"):
		return
	root.set_meta("closing", true)
	remove_meta("ai_note")
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_end.bind(root))
	tw.tween_callback(Music.set_game_running.bind(Music.game_running))


## A piano sung by Boyfriend (see Chromatics).
func chromatics() -> void:
	if active:
		return
	active = true
	var piano := Chromatics.new()
	piano.closed.connect(func(): active = false)
	add_child(piano)


## Hi, I'm Compost.
func compost() -> void:
	if active:
		return
	Achievements.unlock("compost")
	_play_video(COMPOST_VIDEO)


## Plays No More Tears full-screen, then drops you back where you were.
func gooseworx() -> void:
	if active:
		return
	Achievements.unlock("gooseworx")
	_play_video(NO_MORE_TEARS)


## Plays a video full-screen with the music paused, then fades back.
func _play_video(path: String) -> void:
	if active:
		return
	active = true
	var root := ColorRect.new()
	root.color = Color.BLACK
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := AspectRatioContainer.new()
	frame.ratio = 16.0 / 9.0
	root.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var video := VideoStreamPlayer.new()
	video.stream = load(path)
	video.expand = true
	frame.add_child(video)
	video.finished.connect(_end_video.bind(root))
	Music.player.stream_paused = true
	video.play()


func _end_video(root: Control) -> void:
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_end.bind(root))
	# Restores the music to whatever the user/game state says it should be.
	tw.tween_callback(Music.set_game_running.bind(Music.game_running))
