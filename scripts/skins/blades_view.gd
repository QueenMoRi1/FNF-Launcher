class_name BladesView
extends SkinView
## Xbox 360 "Blades" (2005) style library: blade tabs on the left, a glossy
## white games list with a green highlight, and the selected mod's art.
## The background is the real Blades wallpaper, downloaded from the Internet
## Archive on first use and cached (it's Microsoft's, so it isn't shipped).

const BG_URL := "https://archive.org/download/xbox-blades/Xbox%20Blades%20Background/green-circles.jpg"
const BG_CACHE := "user://blades/green-circles.jpg"
const GREEN := Color("8cd82e")
const GREEN_DARK := Color("4e9a06")
const INK := Color("2b2b2b")
const TABS := ["marketplace", "xbox live", "games", "media", "system"]
const ACTIVE_TAB := 2
const ROW_H := 50.0
const LIST := Rect2(110, 128, 520, 500) # games list panel (1280x720 layout)
const ASSETS := "res://assets/funkin/"

var bg: TextureRect
var rows: Array[Control] = []
var list_clip: Control
var list_inner: Control
var art: TextureRect
var title_label: Label
var info_label: Label
var _scroll := 0.0


func _init() -> void:
	super()
	accent = GREEN


func _build(empty_hint: String) -> void:
	# Background: a green gradient until the real wallpaper is cached.
	var base := TextureRect.new()
	base.texture = _gradient(Color("6ab521"), Color("1d5a0c"))
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(base)
	base.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg = TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background_nodes = [base, bg]
	_load_background()

	_build_tabs(_group("tabs"))
	var head := _group("header")
	var header := UiKit.add_label(head, "games", 46, Color.WHITE)
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_theme_font_override("font", _font(300))
	header.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	header.add_theme_constant_override("shadow_offset_y", 2)
	header.position = Vector2(LIST.position.x + 6, 52)
	var sub := UiKit.add_label(head, "fnf mods", 20, Color(1, 1, 1, 0.8))
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.add_theme_font_override("font", _font(400))
	sub.position = Vector2(LIST.position.x + 6 + header.get_minimum_size().x + 14, 72)

	# The glossy list panel.
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0.88), 10))
	panel.position = LIST.position
	panel.size = LIST.size
	_group("list").add_child(panel)
	var gloss := TextureRect.new()
	gloss.texture = _gradient(Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0))
	gloss.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gloss.stretch_mode = TextureRect.STRETCH_SCALE
	gloss.position = Vector2(6, 4)
	gloss.size = Vector2(LIST.size.x - 12, 60)
	panel.add_child(gloss)
	list_clip = Control.new()
	list_clip.clip_contents = true
	list_clip.position = Vector2(10, 12)
	list_clip.size = LIST.size - Vector2(20, 24)
	panel.add_child(list_clip)
	list_inner = Control.new()
	list_clip.add_child(list_inner)
	for i in items.size():
		var row := _make_row(items[i])
		row.position = Vector2(0, i * ROW_H)
		list_inner.add_child(row)
		rows.append(row)

	# Right side: the mod's art in a white frame, and its details.
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0.92), 8))
	frame.position = Vector2(LIST.end.x + 40, LIST.position.y + 40)
	frame.size = Vector2(500, 290)
	var details := _group("details")
	details.add_child(frame)
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	art.position = Vector2(8, 8)
	art.size = frame.size - Vector2(16, 16)
	frame.add_child(art)
	title_label = UiKit.add_label(details, "", 30, Color.WHITE)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_override("font", _font(600))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.position = frame.position + Vector2(4, frame.size.y + 16)
	title_label.size = Vector2(frame.size.x, 44)
	info_label = UiKit.add_label(details, "", 20, Color(1, 1, 1, 0.85))
	info_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	info_label.add_theme_font_override("font", _font(400))
	info_label.position = title_label.position + Vector2(0, 46)

	if items.is_empty():
		frame.hide()
		title_label.text = "no games yet"
		info_label.text = empty_hint.replace("\n", " ")


func set_selected(i: int, instant := false) -> void:
	selected = i
	if items.is_empty():
		return
	for r in rows.size():
		var on := r == selected
		rows[r].get_node("Hi").visible = on
		(rows[r].get_node("Name") as Label).add_theme_color_override("font_color", Color.WHITE if on else INK)
	# Keep the selection in view, a couple of rows from the edge.
	var visible_rows := floorf(list_clip.size.y / ROW_H)
	var target := clampf(selected - floorf(visible_rows / 2.0), 0.0, maxf(items.size() - visible_rows, 0.0)) * ROW_H
	if instant:
		_scroll = target
	list_inner.set_meta("target", target)
	var item: Dictionary = items[selected]
	title_label.text = item.entry.name
	var songs: int = item.entry.get("songs", []).size()
	info_label.text = "%d songs   ·   press A to play" % songs
	art.texture = item.art if item.art else item.icon
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if item.art else TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func item_at(pos: Vector2) -> int:
	for r in rows.size():
		if rows[r].get_global_rect().has_point(pos) and list_clip.get_global_rect().has_point(pos):
			return r
	return -1


func play_launch(i: int, done: Callable) -> void:
	if i < 0 or i >= rows.size():
		done.call()
		return
	var hi: Control = rows[i].get_node("Hi")
	var tw := create_tween()
	for k in 2:
		tw.tween_property(hi, "modulate", Color(1.5, 1.5, 1.5), 0.08)
		tw.tween_property(hi, "modulate", Color.WHITE, 0.12)
	tw.tween_interval(0.3)
	tw.tween_callback(done)


func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = _font(400)
	t.default_font_size = 22
	# Dialogs: dark like the 360's guide, with a green edge.
	var panel := _panel_style(Color(0.1, 0.1, 0.1, 0.95), 10)
	panel.set_content_margin_all(28)
	panel.set_border_width_all(3)
	panel.border_color = GREEN_DARK
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 20
	t.set_stylebox("panel", "PanelContainer", panel)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.85, 0.85, 0.85)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(10)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = GREEN_DARK
	for kind in ["Button", "OptionButton", "LineEdit"]:
		t.set_stylebox("normal", kind, normal)
		t.set_stylebox("hover", kind, focus)
		t.set_stylebox("pressed", kind, focus)
		t.set_stylebox("focus", kind, focus)
		t.set_color("font_color", kind, INK)
		t.set_color("font_focus_color", kind, Color.WHITE)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, Color.WHITE)
	var widget := _panel_style(Color(0.08, 0.08, 0.08, 0.85), 8)
	widget.set_border_width_all(2)
	widget.border_color = GREEN_DARK
	widget.set_content_margin_all(12)
	UiKit.add_widget_style(t, widget)
	return t


func sounds() -> Dictionary:
	return {
		"scroll": load(ASSETS + "scrollMenu.ogg"),
		"confirm": load(ASSETS + "confirmMenu.ogg"),
		"cancel": load(ASSETS + "cancelMenu.ogg"),
	}


func _process(delta: float) -> void:
	if list_inner and list_inner.has_meta("target"):
		_scroll = lerpf(_scroll, list_inner.get_meta("target"), 1.0 - exp(-delta * 14.0))
		list_inner.position.y = -_scroll


func _make_row(item: Dictionary) -> Control:
	var row := Control.new()
	row.size = Vector2(LIST.size.x - 20, ROW_H)
	var hi := TextureRect.new()
	hi.name = "Hi"
	hi.texture = _gradient(GREEN, GREEN_DARK)
	hi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hi.stretch_mode = TextureRect.STRETCH_SCALE
	hi.size = row.size - Vector2(0, 4)
	hi.position.y = 2
	hi.visible = false
	row.add_child(hi)
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(8, 5)
	icon.size = Vector2(40, 40)
	row.add_child(icon)
	var name_label := UiKit.add_label(row, item.entry.name, 22, INK)
	name_label.name = "Name"
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_override("font", _font(500))
	name_label.add_theme_constant_override("outline_size", 0)
	name_label.position = Vector2(60, 9)
	name_label.size = Vector2(row.size.x - 70, 32)
	return row


## The blades: stacked tabs on the left edge, the active one brightest.
func _build_tabs(holder: Control) -> void:
	for i in TABS.size():
		var on := i == ACTIVE_TAB
		var tab := Panel.new()
		tab.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0.85 if on else 0.35), 6))
		# Fanned out: inactive blades peek out behind the active one.
		tab.position = Vector2(14 + i * 18, 128 + absi(i - ACTIVE_TAB) * 10)
		tab.size = Vector2(44, 500 - absi(i - ACTIVE_TAB) * 20)
		tab.z_index = -1 if not on else 0
		holder.add_child(tab)
		var label := UiKit.add_label(tab, TABS[i], 18, GREEN_DARK if on else Color(1, 1, 1, 0.9))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.add_theme_font_override("font", _font(600 if on else 400))
		label.add_theme_constant_override("outline_size", 0)
		label.rotation = -PI / 2.0
		label.position = Vector2(10, tab.size.y - 20)
	# Only the active blade's label should read clearly over the stack.
	holder.move_child(holder.get_child(ACTIVE_TAB), -1)


func _load_background() -> void:
	if FileAccess.file_exists(BG_CACHE):
		_show_background(Image.load_from_file(ProjectSettings.globalize_path(BG_CACHE)))
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers, body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var img := Image.new()
		if img.load_jpg_from_buffer(body) == OK:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BG_CACHE.get_base_dir()))
			var f := FileAccess.open(BG_CACHE, FileAccess.WRITE)
			if f:
				f.store_buffer(body)
			_show_background(img))
	http.request(BG_URL)


func _show_background(img: Image) -> void:
	if img == null or not is_instance_valid(bg):
		return
	if img.get_width() > 2560:
		img.resize(2560, roundi(img.get_height() * 2560.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	bg.texture = ImageTexture.create_from_image(img)
	bg.modulate.a = 0.0
	create_tween().tween_property(bg, "modulate:a", 1.0, 0.4)


static func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 8
	return s


static func _font(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Sans-Serif"])
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
