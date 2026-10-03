class_name SteamView
extends SkinView
## Steam Big Picture / Steam Deck style library: hero art, a horizontal row of
## capsules and a green PLAY button. Uses Steam's own UI sounds when installed.

const BG_TOP := Color("1b2838")
const BG_BOTTOM := Color("0e141b")
const BLUE := Color("1a9fff")
const GREEN_TOP := Color("75b022")
const GREEN_BOTTOM := Color("588a1b")
const CAPSULE := Vector2(170, 255)
const GAP := 22.0
const ROW_Y := 0.56 # row top, as a fraction of the screen height
const LEFT := 64.0
const SOUND_DIR := "steamui/sounds"
const BLUR_SHADER := """
shader_type canvas_item;
void fragment() {
	COLOR = textureLod(TEXTURE, UV, 3.5) * COLOR;
}
"""

var hero: TextureRect
var capsules: Array[Control] = []
var title_label: Label
var info_label: Label
var play_button: PanelContainer
var play_label: Label
var clock: Label
var proton_name := ""


func _init() -> void:
	super()
	nav_axis = Axis.HORIZONTAL
	widget_top = 72.0 # under the clock, clear of the capsule row
	accent = BLUE


func _build(empty_hint: String) -> void:
	var ge := Proton.find_ge_proton()
	proton_name = Proton.version_name(ge) if ge != "" else "NO GE-PROTON"
	var bg := TextureRect.new()
	bg.texture = _gradient(BG_TOP, BG_BOTTOM)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	hero = TextureRect.new()
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = BLUR_SHADER
	hero.material = mat
	hero.modulate = Color(0.55, 0.55, 0.55, 0.0)
	add_child(hero)
	hero.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	hero.offset_bottom = 520
	# Fade the hero art into the background color.
	var fade := TextureRect.new()
	fade.texture = _gradient(Color(BG_BOTTOM, 0.0), BG_BOTTOM)
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(fade)
	fade.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	fade.offset_top = 200
	fade.offset_bottom = 520

	background_nodes = [bg]
	mod_art_nodes = [hero, fade]
	var header := _group("header")
	var games := _group("games")
	var top := UiKit.add_label(header, "LIBRARY", 26, Color.WHITE)
	top.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.position = Vector2(LEFT, 24)
	var tab := UiKit.add_label(header, "FNF MODS", 18, BLUE)
	tab.autowrap_mode = TextServer.AUTOWRAP_OFF
	tab.position = Vector2(LEFT + 150, 31)
	clock = UiKit.add_label(self, "", 22, Color(0.85, 0.87, 0.9))
	parts["clock"] = clock
	clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	clock.offset_left = -220
	clock.offset_right = -LEFT
	clock.offset_top = 26
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	title_label = UiKit.add_label(header, "", 52, Color.WHITE)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_override("font", _font(700))
	title_label.position = Vector2(LEFT, 120)
	title_label.size = Vector2(900, 70)

	var play_row := HBoxContainer.new()
	play_row.add_theme_constant_override("separation", 22)
	play_row.position = Vector2(LEFT, 205)
	header.add_child(play_row)
	play_button = PanelContainer.new()
	var green := StyleBoxTexture.new()
	green.texture = _gradient(GREEN_TOP, GREEN_BOTTOM)
	green.set_content_margin_all(0)
	green.content_margin_left = 34
	green.content_margin_right = 40
	green.content_margin_top = 10
	green.content_margin_bottom = 10
	play_button.add_theme_stylebox_override("panel", green)
	play_row.add_child(play_button)
	play_label = UiKit.add_label(play_button, "▶  PLAY", 24, Color.WHITE)
	play_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	play_label.add_theme_font_override("font", _font(700))
	info_label = UiKit.add_label(play_row, "", 18, Color(0.6, 0.66, 0.72))
	info_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	info_label.size_flags_vertical = SIZE_SHRINK_CENTER

	for item in items:
		var cap := _make_capsule(item)
		games.add_child(cap)
		capsules.append(cap)

	if items.is_empty():
		play_button.hide()
		title_label.text = "Your library is empty"
		info_label.text = empty_hint.replace("\n", " ")


func set_selected(i: int, instant := false) -> void:
	selected = i
	if items.is_empty():
		return
	for c in capsules.size():
		var cap := capsules[c]
		var on := c == selected
		cap.get_node("Outline").visible = on
		create_tween().tween_property(cap, "scale", Vector2.ONE * (1.12 if on else 1.0), 0.0 if instant else 0.12)
		cap.modulate = Color.WHITE if on else Color(0.7, 0.7, 0.75)
		if instant:
			cap.position = _capsule_target(c)
	var item: Dictionary = items[selected]
	title_label.text = item.entry.name
	var songs: int = item.entry.get("songs", []).size()
	info_label.text = "%d SONGS   ·   %s" % [songs, proton_name]
	var tex: Texture2D = item.art
	if tex != hero.texture:
		hero.texture = tex
		hero.modulate.a = 0.0
		if tex:
			create_tween().tween_property(hero, "modulate:a", 1.0, 0.3)
	for c in capsules.size():
		_update_capsule_art(c)


func item_at(pos: Vector2) -> int:
	for c in capsules.size():
		if capsules[c].get_global_rect().has_point(pos):
			return c
	return -1


func play_launch(_i: int, done: Callable) -> void:
	play_label.text = "LAUNCHING..."
	var tw := create_tween()
	tw.tween_property(play_button, "modulate", Color(1.6, 1.6, 1.6), 0.12)
	tw.tween_property(play_button, "modulate", Color.WHITE, 0.3)
	tw.tween_interval(0.5)
	tw.tween_callback(play_label.set_text.bind("▶  PLAY"))
	tw.tween_callback(done)


func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = _font(400)
	t.default_font_size = 22
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("23262e")
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(28)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 24
	t.set_stylebox("panel", "PanelContainer", panel)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("3d4450")
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(10)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color("dcdedf")
	for kind in ["Button", "OptionButton", "LineEdit"]:
		t.set_stylebox("normal", kind, normal)
		t.set_stylebox("hover", kind, focus)
		t.set_stylebox("pressed", kind, focus)
		t.set_stylebox("focus", kind, focus)
		t.set_color("font_focus_color", kind, Color("1b2838"))
		t.set_color("font_hover_color", kind, Color("1b2838"))
		t.set_color("font_pressed_color", kind, Color("1b2838"))
	var widget := StyleBoxFlat.new()
	widget.bg_color = Color(0.09, 0.11, 0.14, 0.92)
	widget.set_corner_radius_all(8)
	widget.set_content_margin_all(12)
	UiKit.add_widget_style(t, widget)
	return t


func sounds() -> Dictionary:
	return {
		"scroll": _steam_sound("deck_ui_navigation.wav"),
		"confirm": _steam_sound("deck_ui_launch_game.wav"),
		"cancel": _steam_sound("deck_ui_hide_modal.wav"),
	}


func _process(delta: float) -> void:
	# Long titles stop short of the jukebox in the top-right corner.
	title_label.size.x = maxf(300.0, size.x - LEFT - 480.0)
	var t := 1.0 - exp(-delta * 12.0)
	for c in capsules.size():
		capsules[c].position = capsules[c].position.lerp(_capsule_target(c), t)
	var now := Time.get_datetime_dict_from_system()
	var hour: int = now.hour % 12 if now.hour % 12 != 0 else 12
	clock.text = "%d:%02d %s" % [hour, now.minute, "PM" if now.hour >= 12 else "AM"]


func _capsule_target(c: int) -> Vector2:
	return Vector2(LEFT + (c - selected) * (CAPSULE.x + GAP), size.y * ROW_Y)


func _make_capsule(item: Dictionary) -> Control:
	var cap := Control.new()
	cap.size = CAPSULE
	cap.pivot_offset = Vector2(CAPSULE.x / 2, CAPSULE.y)
	cap.clip_contents = false
	# Without art: icon on a card tinted with the icon's color.
	var card := Panel.new()
	card.name = "Card"
	var style := StyleBoxFlat.new()
	style.bg_color = item.color.darkened(0.55)
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", style)
	cap.add_child(card)
	card.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(20, 30)
	icon.size = Vector2(CAPSULE.x - 40, CAPSULE.x - 40)
	card.add_child(icon)
	var name_label := UiKit.add_label(card, item.entry.name, 18, Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(10, CAPSULE.x + 10)
	name_label.size = Vector2(CAPSULE.x - 20, 70)
	# With art: the GameBanana art cropped to the capsule.
	var art := TextureRect.new()
	art.name = "Art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	cap.add_child(art)
	art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var outline := Panel.new()
	outline.name = "Outline"
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(3)
	ring.border_color = Color.WHITE
	ring.set_corner_radius_all(5)
	ring.set_expand_margin_all(3)
	outline.add_theme_stylebox_override("panel", ring)
	cap.add_child(outline)
	outline.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return cap


func _update_capsule_art(c: int) -> void:
	var art: TextureRect = capsules[c].get_node("Art")
	var tex: Texture2D = items[c].art
	art.texture = tex
	art.visible = tex != null
	capsules[c].get_node("Card").visible = tex == null


static func _steam_sound(file: String) -> AudioStream:
	for root in Proton.steam_roots():
		var path := root.path_join(SOUND_DIR).path_join(file)
		if FileAccess.file_exists(path):
			return AudioStreamWAV.load_from_file(path)
	return null


static func _font(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans", "Sans-Serif"])
	f.font_weight = weight
	return f


static func _gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	return tex
