extends Control
## FNF-style beat-synced intro, then straight into the launcher menu.

const BEAT := 60.0 / Music.MENU_BPM
const ORANGE := "res://assets/orang/real_orang.png"
const LINE_HEIGHT := 70.0
const MAX_LINE_WIDTH := 1180.0

var quip: Array = Quips.pick()
var last_beat := 0
var lines: VBoxContainer
var orange: TextureRect
var done := false


func _ready() -> void:
	InputSetup.apply()
	theme = UiKit.make_theme()
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Matches createCoolText: lines 60px apart starting at y = 200.
	lines = VBoxContainer.new()
	lines.add_theme_constant_override("separation", int(60 - LINE_HEIGHT))
	add_child(lines)
	lines.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	lines.offset_top = 200

	orange = TextureRect.new()
	orange.texture = load(ORANGE)
	orange.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	orange.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	orange.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(orange)
	orange.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	orange.offset_left = -130
	orange.offset_right = 130
	orange.offset_top = 360
	orange.offset_bottom = 620
	orange.pivot_offset = Vector2(130, 130)
	orange.hide()

	Music.play_menu_theme()


func _process(_delta: float) -> void:
	if done:
		return
	var t := Music.position() + AudioServer.get_time_since_last_mix()
	var beat := int(t / BEAT)
	while last_beat < beat and not done:
		last_beat += 1
		_beat_hit(last_beat)
	if Input.is_action_just_pressed("ui_accept"):
		_finish()


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_finish()


func _beat_hit(beat: int) -> void:
	match beat:
		1:
			_set_text(["made by"])
		3:
			_add_text("orang entertainment")
			_show_orange()
		4:
			_clear()
		5:
			_set_text(["borrowing assets", "from"])
		7:
			_add_text("the fnf idiots")
		8:
			_clear()
		9:
			_set_text([quip[0]])
		11:
			_add_text(quip[1])
		12:
			_clear()
		13:
			_add_text("friday")
		14:
			_add_text("nigth" if quip[0] == "trending" else "night")
		15:
			_add_text("funkin")
		16:
			_finish()


func _set_text(texts: Array) -> void:
	_clear()
	for text in texts:
		_add_text(text)


func _add_text(text: String) -> void:
	# Shrink long lines so they fit on screen.
	var height := minf(LINE_HEIGHT, LINE_HEIGHT * MAX_LINE_WIDTH / (text.length() * 52.0))
	var line := Alphabet.make_text(text, height)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.custom_minimum_size.y = LINE_HEIGHT
	lines.add_child(line)


func _clear() -> void:
	for child in lines.get_children():
		child.queue_free()
	orange.hide()


func _show_orange() -> void:
	orange.show()
	orange.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(orange, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _finish() -> void:
	if done:
		return
	done = true
	Music.intro_flash = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
