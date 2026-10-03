class_name ThemeEditor
extends Control
## The in-launcher theme editor: colours, files (browse or drag and drop onto
## the window) and a MOVE THINGS mode for dragging parts around and resizing
## them. Every change is saved to theme.txt and shown on the menu right away.

signal closed

const FILE_NAMES := {
	"background": "Background (image or .ogv video)", "background pattern": "Background pattern (tiled)",
	"logo": "Logo", "font": "Font", "menu music": "Menu music",
	"sound scroll": "Scroll sound", "sound confirm": "Confirm sound", "sound cancel": "Back sound",
	"intro logo": "Intro logo", "quips": "Intro quips (.txt)",
	"cursor": "Mouse cursor (.png)", "achievement sound": "Achievement sound",
}
const COLOR_NAMES := {
	"accent": "Accent", "text": "Text", "panel": "Popups", "button": "Buttons",
	"button focus": "Selected button", "background color": "Background colour",
	"particles color": "Particles", "achievement color": "Achievement popup",
}
const PANEL_WIDTH := 420.0
const HANDLE := 18.0

var main: Node
var t: CustomTheme
var panel: PanelContainer
var file_labels := {}
var part_boxes: VBoxContainer
var move_button: Button
var status: Label
var rebuild_timer: Timer
var moving := false
var on_left := false
var hover := ""
var drag := {} # {id, kind, mouse, start}


func setup(main_node: Node, theme_to_edit: CustomTheme) -> ThemeEditor:
	main = main_node
	t = theme_to_edit
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	rebuild_timer = Timer.new()
	rebuild_timer.one_shot = true
	rebuild_timer.wait_time = 0.25
	rebuild_timer.timeout.connect(_rebuild)
	add_child(rebuild_timer)
	_build_panel()


# --- The side panel ---------------------------------------------------------------------

func _build_panel() -> void:
	if panel:
		panel.queue_free()
	panel = PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_STOP
	# The theme's colours, but always the launcher's own font: a wide or fancy
	# theme font would push the editor's controls off the screen.
	var look: Theme = main.theme.duplicate() if main.theme else Theme.new()
	look.default_font = UiKit.make_theme().default_font
	panel.theme = look
	add_child(panel)
	_dock()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	var title := UiKit.add_label(top, "THEME EDITOR", 26, UiKit.accent)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	_small_button(top, "⇆", _swap_side).tooltip_text = "Move this panel to the other side"
	status = UiKit.add_label(box, "Changes save automatically.", 14, Color(1, 1, 1, 0.6))

	_heading(box, "NAME")
	var name_edit := LineEdit.new()
	name_edit.text = t.name()
	name_edit.text_changed.connect(func(v: String): t.values["name"] = v; _changed(false))
	box.add_child(name_edit)

	_heading(box, "LAYOUT UNDERNEATH")
	var base := OptionButton.new()
	for b in ["freeplay", "steam", "blades"]:
		base.add_item(CustomTheme.BASE_NAMES[b].to_upper())
		if b == t.base():
			base.select(base.item_count - 1)
	base.item_selected.connect(func(i: int):
		t.values["based on"] = CustomTheme.BASE_NAMES[["freeplay", "steam", "blades"][i]]
		_changed(true)
		_refresh_parts.call_deferred())
	box.add_child(base)

	_heading(box, "COLOURS")
	for key in CustomTheme.COLOR_KEYS:
		var row := HBoxContainer.new()
		box.add_child(row)
		var l := UiKit.add_label(row, COLOR_NAMES[key], 18)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		var pick := ColorPickerButton.new()
		pick.custom_minimum_size = Vector2(90, 34)
		pick.edit_alpha = key in ["panel", "button", "button focus"]
		pick.color = t.color(key, _current_color(key))
		pick.color_changed.connect(func(c: Color): t.values[key] = CustomTheme.color_text(c); _changed(true))
		row.add_child(pick)
		_small_button(row, "✕", func():
			t.values.erase(key)
			pick.color = _current_color(key)
			_changed(true)).tooltip_text = "Back to the layout's own colour"

	_heading(box, "BACKGROUND")
	var dim_row := HBoxContainer.new()
	box.add_child(dim_row)
	UiKit.add_label(dim_row, "Darken", 18).custom_minimum_size.x = 90
	var dim := HSlider.new()
	dim.min_value = 0
	dim.max_value = 90
	dim.step = 5
	dim.value = t.percent("background dim", 0.0)
	dim.size_flags_horizontal = SIZE_EXPAND_FILL
	dim.value_changed.connect(func(v: float): t.values["background dim"] = "%d%%" % int(v); _changed(true))
	dim_row.add_child(dim)
	var art := CheckButton.new()
	art.text = "Show each mod's art"
	art.button_pressed = t.mod_art()
	art.toggled.connect(func(on: bool): t.values["mod art"] = "on" if on else "off"; _changed(true))
	box.add_child(art)

	# Gradient: two colours top to bottom (on top of the background colour).
	var grad_row := HBoxContainer.new()
	box.add_child(grad_row)
	var grad_on := CheckBox.new()
	grad_on.text = "Gradient"
	var gc := t.colors("background gradient")
	grad_on.button_pressed = gc.size() >= 2
	grad_row.add_child(grad_on)
	var g1 := ColorPickerButton.new()
	var g2 := ColorPickerButton.new()
	g1.color = gc[0] if gc.size() >= 2 else Color("1b1035")
	g2.color = gc[1] if gc.size() >= 2 else Color("ff4f8a")
	for g in [g1, g2]:
		g.custom_minimum_size = Vector2(70, 34)
		grad_row.add_child(g)
	var set_grad := func(_x = null) -> void:
		if grad_on.button_pressed:
			t.values["background gradient"] = "#%s #%s" % [g1.color.to_html(false), g2.color.to_html(false)]
		else:
			t.values.erase("background gradient")
		_changed(true)
	grad_on.toggled.connect(set_grad)
	g1.color_changed.connect(set_grad)
	g2.color_changed.connect(set_grad)

	_heading(box, "ANIMATED BACKGROUND")
	var kinds := ["none"] + ThemeParticles.KINDS
	var kind_pick := OptionButton.new()
	for k in kinds:
		kind_pick.add_item(k.to_upper())
	kind_pick.select(maxi(kinds.find(str(t.values.get("particles", "none")).to_lower()), 0))
	kind_pick.item_selected.connect(func(i: int):
		if i == 0:
			t.values.erase("particles")
		else:
			t.values["particles"] = kinds[i]
		_changed(true))
	box.add_child(kind_pick)
	for pair in [["particles amount", "Amount", 0.0, 300.0], ["particles speed", "Speed", 10.0, 400.0], ["particles size", "Size", 30.0, 400.0]]:
		_slider(box, pair[1], pair[0], pair[2], pair[3], 100.0)

	_heading(box, "INTRO")
	var skip := CheckButton.new()
	skip.text = "Skip the intro"
	skip.button_pressed = str(t.values.get("intro", "")).to_lower() == "skip"
	skip.toggled.connect(func(on: bool):
		if on:
			t.values["intro"] = "skip"
		else:
			t.values.erase("intro")
		_changed(false))
	box.add_child(skip)
	_text_setting(box, "Intro credit (a | b)", "intro credit")
	_text_setting(box, "Intro title (a | b | c)", "intro title")

	_heading(box, "CHART VIEWER")
	var arrows_row := HBoxContainer.new()
	box.add_child(arrows_row)
	UiKit.add_label(arrows_row, "Arrows", 18).size_flags_horizontal = SIZE_EXPAND_FILL
	var cur_arrows := t.colors("arrow colors")
	var arrow_picks := []
	for i in 4:
		var ap := ColorPickerButton.new()
		ap.custom_minimum_size = Vector2(40, 34)
		ap.color = cur_arrows[i] if cur_arrows.size() == 4 else ChartViewer.LANE_COLORS[i]
		arrows_row.add_child(ap)
		arrow_picks.append(ap)
	for ap in arrow_picks:
		ap.color_changed.connect(func(_c: Color):
			t.values["arrow colors"] = " ".join(arrow_picks.map(func(x): return "#" + x.color.to_html(false)))
			_changed(false))
	for f in [["viewer kaleidoscope", "Kaleidoscope"], ["viewer shake", "Beat shake"], ["viewer ribbons", "Light ribbons"]]:
		var cb := CheckButton.new()
		cb.text = f[1]
		cb.button_pressed = t.flag(f[0], true)
		cb.toggled.connect(func(on: bool): t.values[f[0]] = "on" if on else "off"; _changed(false))
		box.add_child(cb)
	var accent_vis := CheckButton.new()
	accent_vis.text = "Accent visualizer"
	accent_vis.button_pressed = str(t.values.get("visualizer colors", "rainbow")).to_lower() != "rainbow"
	accent_vis.toggled.connect(func(on: bool):
		t.values["visualizer colors"] = ("#" + t.color("accent", UiKit.accent).to_html(false)) if on else "rainbow"
		_changed(false))
	box.add_child(accent_vis)
	_slider(box, "Effects", "viewer effects", 0.0, 200.0, 100.0)

	_heading(box, "EXTRAS")
	_slider(box, "UI size", "ui scale", 60.0, 200.0, 100.0)
	var pos_pick := OptionButton.new()
	var spots := ["top", "bottom", "top left", "top right", "bottom left", "bottom right"]
	for spot in spots:
		pos_pick.add_item("Popups: " + spot)
	pos_pick.select(maxi(spots.find(str(t.values.get("achievement position", "top")).to_lower()), 0))
	pos_pick.item_selected.connect(func(i: int): t.values["achievement position"] = spots[i]; _changed(false))
	box.add_child(pos_pick)
	_text_setting(box, "Season (e.g. october, november)", "season")

	_heading(box, "FILES")
	UiKit.add_label(box, "Tip: drag and drop files onto the window!", 15, Color(1, 1, 1, 0.7))
	for key in CustomTheme.FILE_KEYS:
		UiKit.add_label(box, FILE_NAMES[key], 16, Color(1, 1, 1, 0.85))
		var row := HBoxContainer.new()
		box.add_child(row)
		var l := UiKit.add_label(row, "", 15)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		file_labels[key] = l
		_small_button(row, "BROWSE", _browse.bind(key))
		_small_button(row, "✕", func(): t.values.erase(key); _changed(true); _refresh_files())
	_refresh_files()

	_heading(box, "MOVE THINGS")
	move_button = UiKit.add_button(box, "", _toggle_layout)
	UiKit.add_label(box, "Drag a part to move it. Drag its corner (or scroll) to resize. Right-click resets it.", 15, Color(1, 1, 1, 0.7))
	part_boxes = VBoxContainer.new()
	box.add_child(part_boxes)
	UiKit.add_button(box, "RESET LAYOUT", func():
		t.moves.clear()
		t.hidden.clear()
		_changed(true)
		_refresh_parts.call_deferred())
	_refresh_parts()
	_update_move_button()

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	box.add_child(bottom)
	_small_button(bottom, "OPEN FOLDER", func(): OS.shell_open(t.folder))
	_small_button(bottom, "EXPORT", main._export_theme)
	_small_button(bottom, "DONE", func(): closed.emit())


## A labelled % slider for theme key `key`.
func _slider(box: Control, label: String, key: String, lo: float, hi: float, fallback: float) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := UiKit.add_label(row, label, 16)
	l.custom_minimum_size.x = 90
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 5
	s.value = t.percent(key, fallback)
	s.size_flags_horizontal = SIZE_EXPAND_FILL
	var shown := UiKit.add_label(row, "%d%%" % int(s.value), 16)
	shown.custom_minimum_size.x = 56
	row.add_child(s)
	row.move_child(shown, -1)
	s.value_changed.connect(func(v: float):
		shown.text = "%d%%" % int(v)
		t.values[key] = "%d%%" % int(v)
		_changed(true))


## A labelled one-line text setting for theme key `key`.
func _text_setting(box: Control, label: String, key: String) -> void:
	UiKit.add_label(box, label, 15, Color(1, 1, 1, 0.8))
	var e := LineEdit.new()
	e.text = str(t.values.get(key, ""))
	e.text_changed.connect(func(v: String):
		if v.strip_edges() == "":
			t.values.erase(key)
		else:
			t.values[key] = v.strip_edges()
		_changed(false))
	box.add_child(e)


func _dock() -> void:
	panel.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE if on_left else PRESET_RIGHT_WIDE)
	if on_left:
		panel.offset_left = 0
		panel.offset_right = PANEL_WIDTH
	else:
		panel.offset_left = -PANEL_WIDTH
		panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = -44


func _swap_side() -> void:
	on_left = not on_left
	_dock()


func _heading(box: Control, text: String) -> void:
	var l := UiKit.add_label(box, text, 18, UiKit.accent)
	l.add_theme_constant_override("outline_size", 4)


func _small_button(parent: Control, text: String, on_press: Callable) -> Button:
	var b := UiKit.add_button(parent, text, on_press)
	b.add_theme_font_size_override("font_size", 16)
	return b


## The colour the menu uses now, for a key with no theme value.
func _current_color(key: String) -> Color:
	var th: Theme = main.theme
	match key:
		"accent":
			return UiKit.accent
		"text":
			return Color.WHITE
		"panel":
			var p := th.get_stylebox("panel", "PanelContainer") if th else null
			return p.bg_color if p is StyleBoxFlat else Color(0, 0, 0, 0.88)
		"button", "button focus":
			var s := th.get_stylebox("normal" if key == "button" else "focus", "Button") if th else null
			return s.bg_color if s is StyleBoxFlat else Color(0.2, 0.2, 0.25)
	return Color.BLACK


func _refresh_files() -> void:
	for key in file_labels:
		var v: String = t.values.get(key, "")
		file_labels[key].text = v if v != "" else "—"


func _refresh_parts() -> void:
	for c in part_boxes.get_children():
		c.queue_free()
	var parts := ThemeRuntime.parts_of(main)
	for id in parts:
		var cb := CheckBox.new()
		cb.text = ThemeRuntime.PART_NAMES.get(id, id.capitalize())
		cb.button_pressed = not id in t.hidden
		cb.add_theme_font_size_override("font_size", 16)
		cb.toggled.connect(func(on: bool):
			if on:
				t.hidden.erase(id)
			elif not id in t.hidden:
				t.hidden.append(id)
			t.save()
			ThemeRuntime.layout(t, main)
			queue_redraw())
		part_boxes.add_child(cb)


func _browse(key: String) -> void:
	var filters := PackedStringArray()
	for ext in CustomTheme.FILE_TYPES[key]:
		filters.append("*." + ext)
	main._pick_file(false, filters, OS.get_environment("HOME"), _assign.bind(key))


func _assign(path: String, key: String) -> void:
	t.values[key] = t.add_file(path)
	_changed(true)
	_refresh_files()
	status.text = "Added %s as the %s." % [path.get_file(), FILE_NAMES[key].to_lower()]


## Files dropped onto the window: put each where it fits, asking if it could go in several places.
func drop(files: PackedStringArray) -> void:
	for f in files:
		var ext := f.get_extension().to_lower()
		var slots := []
		for key in CustomTheme.FILE_KEYS:
			if ext in CustomTheme.FILE_TYPES[key]:
				slots.append(key)
		if slots.is_empty():
			status.text = "%s isn't something a theme can use." % f.get_file()
		elif slots.size() == 1:
			_assign(f, slots[0])
		else:
			var menu := PopupMenu.new()
			menu.add_separator("Use %s as..." % f.get_file())
			for i in slots.size():
				menu.add_item(FILE_NAMES[slots[i]], i)
			menu.id_pressed.connect(func(i: int): _assign(f, slots[i]))
			menu.popup_hide.connect(menu.queue_free)
			add_child(menu)
			menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i(320, 0)))
			return # one question at a time


func _changed(rebuild: bool) -> void:
	t.save()
	status.text = "Saved."
	if rebuild:
		rebuild_timer.start()


func _rebuild() -> void:
	main._apply_skin()
	queue_redraw()


# --- MOVE THINGS mode -------------------------------------------------------------------

func _toggle_layout() -> void:
	moving = not moving
	mouse_filter = MOUSE_FILTER_STOP if moving else MOUSE_FILTER_IGNORE
	_update_move_button()
	queue_redraw()


func _update_move_button() -> void:
	move_button.text = "MOVE THINGS: " + ("ON (click again when done)" if moving else "OFF")


func _rects() -> Dictionary:
	var out := {}
	var screen := get_viewport_rect()
	var parts := ThemeRuntime.parts_of(main)
	for id in parts:
		var n: Control = parts[id]
		if is_instance_valid(n) and n.is_visible_in_tree():
			var r := ThemeRuntime.part_rect(n, screen)
			if r.has_area():
				out[id] = r
	return out


## The part under the mouse: corner handles first, then the smallest area.
func _pick(pos: Vector2) -> Dictionary:
	var rects := _rects()
	for id in rects:
		var r: Rect2 = rects[id]
		if Rect2(r.end - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE)).grow(4).has_point(pos):
			return {"id": id, "kind": "scale"}
	var best := ""
	for id in rects:
		if rects[id].has_point(pos) and (best == "" or rects[id].get_area() < rects[best].get_area()):
			best = id
	return {"id": best, "kind": "move"} if best != "" else {}


func _gui_input(event: InputEvent) -> void:
	if not moving:
		return
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	if mb and mb.pressed:
		var hit := _pick(mb.position)
		if hit.is_empty():
			return
		var m: Array = t.moves.get(hit.id, [0.0, 0.0, 100.0]).duplicate()
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				drag = {"id": hit.id, "kind": hit.kind, "mouse": mb.position, "start": m, "rect": _rects()[hit.id]}
			MOUSE_BUTTON_RIGHT:
				t.moves.erase(hit.id)
				_apply_moves()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				m[2] = clampf(m[2] + (5.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -5.0), 20.0, 400.0)
				t.moves[hit.id] = m
				_apply_moves()
		accept_event()
	elif mb and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not drag.is_empty():
		drag = {}
		t.save()
		status.text = "Saved."
		accept_event()
	elif mm:
		if drag.is_empty():
			var h: Dictionary = _pick(mm.position)
			var id: String = h.get("id", "")
			if id != hover:
				hover = id
				queue_redraw()
			return
		var screen := get_viewport_rect().size
		var m: Array = drag.start.duplicate()
		if drag.kind == "move":
			var d: Vector2 = mm.position - drag.mouse
			m[0] = snappedf(m[0] + d.x / screen.x * 100.0, 0.1)
			m[1] = snappedf(m[1] + d.y / screen.y * 100.0, 0.1)
		else:
			var r: Rect2 = drag.rect
			var before: float = (drag.mouse - r.position).length()
			var now: float = (mm.position - r.position).length()
			m[2] = clampf(snappedf(m[2] * now / maxf(before, 1.0), 1.0), 20.0, 400.0)
		t.moves[drag.id] = m
		ThemeRuntime.layout(t, main)
		queue_redraw()
		accept_event()


func _apply_moves() -> void:
	t.save()
	status.text = "Saved."
	ThemeRuntime.layout(t, main)
	queue_redraw()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and not is_instance_valid(main.file_dialog):
		get_viewport().set_input_as_handled()
		if moving:
			_toggle_layout()
		else:
			closed.emit()


func _process(_delta: float) -> void:
	if moving:
		queue_redraw()


func _draw() -> void:
	if not moving:
		return
	var font := get_theme_default_font()
	var rects := _rects()
	for id in rects:
		var r: Rect2 = rects[id]
		var active: bool = id == hover or id == drag.get("id", "")
		draw_rect(r, Color(UiKit.accent, 0.18 if active else 0.06))
		draw_rect(r, Color(UiKit.accent, 1.0 if active else 0.6), false, 3.0 if active else 2.0)
		draw_rect(Rect2(r.end - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE)), UiKit.accent)
		var label: String = ThemeRuntime.PART_NAMES.get(id, id)
		var m: Array = t.moves.get(id, [0.0, 0.0, 100.0])
		if m[2] != 100.0:
			label += "  %d%%" % int(m[2])
		var lp := r.position + Vector2(6, 22)
		draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color.BLACK)
		draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
