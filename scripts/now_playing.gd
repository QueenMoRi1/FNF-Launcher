class_name NowPlaying
extends PanelContainer
## Corner jukebox widget: song name, game, progress, time left, and controls.

var title_label: Label
var game_label: Label
var time_label: Label
var bar: ProgressBar
var pause_button: Button
var shuffle_button: Button


func _init() -> void:
	custom_minimum_size = Vector2(420, 0)
	theme_type_variation = "NowPlayingPanel"

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	title_label = _one_line(UiKit.add_label(box, "", 22, UiKit.accent))
	game_label = _one_line(UiKit.add_label(box, "", 16, Color(0.7, 0.7, 0.7)))

	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.custom_minimum_size = Vector2(0, 10)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.25, 0.25, 0.25)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = UiKit.accent
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fill)
	box.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	time_label = UiKit.add_label(row, "", 18)
	time_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	time_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_button(row, "<<", Music.prev)
	pause_button = _button(row, "||", Music.toggle_pause)
	_button(row, ">>", func(): Music.next(); Achievements.jukebox_skipped())
	shuffle_button = _button(row, "SHUF", func(): Music.set_shuffle(not Music.shuffle))


func _ready() -> void:
	Music.track_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	var length := Music.length()
	var at := Music.position()
	bar.value = at / length if length > 0.0 else 0.0
	time_label.text = "%s  -%s" % [_fmt(at), _fmt(maxf(length - at, 0.0))]
	pause_button.text = ">" if Music.is_paused() else "||"


func _refresh() -> void:
	var track := Music.current()
	title_label.text = track.title.to_upper()
	game_label.text = track.game
	shuffle_button.modulate = Color.WHITE if Music.shuffle else Color(1, 1, 1, 0.4)


func _button(parent: Control, text: String, on_press: Callable) -> Button:
	var button := UiKit.add_button(parent, text, on_press)
	button.focus_mode = FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	return button


func _one_line(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	return label


static func _fmt(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
