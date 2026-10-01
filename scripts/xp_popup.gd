class_name XpPopup
extends RefCounted
## The "Where'd you go?????" Windows XP-style message box (menu idle easter egg).
## Drawn entirely with styleboxes, scaled up for TV distance.

const MESSAGE := "Where'd you go????? why are you leave me behind?"
const BEIGE := Color("ece9d8")
const FRAME := Color("0831d9")


static func build(parent: Control, on_close: Callable) -> UiKit.Overlay:
	var o := UiKit.Overlay.new()
	o.color = Color(0, 0, 0, 0.2)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(o)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.theme = _theme()
	var center := CenterContainer.new()
	o.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var window := PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = FRAME
	frame.set_corner_radius_all(0)
	frame.corner_radius_top_left = 12
	frame.corner_radius_top_right = 12
	frame.set_content_margin_all(5)
	frame.content_margin_top = 0
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 18
	frame.shadow_offset = Vector2(6, 8)
	window.add_theme_stylebox_override("panel", frame)
	window.custom_minimum_size = Vector2(760, 0)
	center.add_child(window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	window.add_child(column)

	# Title bar: Luna blue gradient, title, red close button.
	var bar := PanelContainer.new()
	var bar_style := StyleBoxTexture.new()
	bar_style.texture = _gradient([Color("3d95ff"), Color("0a5fef"), Color("0058ee"), Color("0046c8")])
	bar_style.content_margin_left = 14
	bar_style.content_margin_right = 8
	bar_style.content_margin_top = 8
	bar_style.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", bar_style)
	column.add_child(bar)
	var bar_row := HBoxContainer.new()
	bar.add_child(bar_row)
	var title := Label.new()
	title.text = "FNF Launcher"
	title.add_theme_font_override("font", _font(700))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color("0a246a"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(40, 40)
	var red := StyleBoxFlat.new()
	red.bg_color = Color("e0533d")
	red.set_border_width_all(2)
	red.border_color = Color.WHITE
	red.set_corner_radius_all(5)
	for state in ["normal", "hover", "pressed"]:
		close.add_theme_stylebox_override(state, red)
	close.add_theme_color_override("font_color", Color.WHITE)
	close.add_theme_color_override("font_hover_color", Color.WHITE)
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(on_close)
	bar_row.add_child(close)

	# Body: beige, "?" icon, message, buttons.
	var body := PanelContainer.new()
	var beige := StyleBoxFlat.new()
	beige.bg_color = BEIGE
	beige.set_content_margin_all(28)
	body.add_theme_stylebox_override("panel", beige)
	column.add_child(body)
	var body_col := VBoxContainer.new()
	body_col.add_theme_constant_override("separation", 28)
	body.add_child(body_col)
	var msg_row := HBoxContainer.new()
	msg_row.add_theme_constant_override("separation", 24)
	body_col.add_child(msg_row)
	msg_row.add_child(_question_icon())
	var text := Label.new()
	text.text = MESSAGE
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(560, 0)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_font_size_override("font_size", 28)
	msg_row.add_child(text)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	body_col.add_child(buttons)

	var yes := func() -> void:
		text.text = ":("
		for b in buttons.get_children():
			b.queue_free()
		var ok := _button(buttons, "OK", on_close)
		ok.grab_focus.call_deferred()
	var maybe := func() -> void:
		text.text = "make up your mind."
		var tw := center.create_tween()
		for i in 8:
			tw.tween_property(center, "position", Vector2(randf_range(-18, 18), randf_range(-6, 6)), 0.04)
		tw.tween_property(center, "position", Vector2.ZERO, 0.04)
	var kill := func() -> void:
		Music.player.pitch_scale = 0.9
		on_close.call()

	o.focus_target = _button(buttons, "Yes", yes)
	_button(buttons, "No", on_close)
	_button(buttons, "Maybe", maybe)
	_button(buttons, "Kill him", kill)
	return o


static func _button(parent: Control, label: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(140, 50)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


static func _question_icon() -> Control:
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var circle := StyleBoxFlat.new()
	circle.bg_color = Color("2b5cd8")
	circle.set_corner_radius_all(36)
	circle.set_border_width_all(3)
	circle.border_color = Color("dfe8ff")
	circle.shadow_color = Color(0, 0, 0, 0.3)
	circle.shadow_size = 4
	icon.add_theme_stylebox_override("panel", circle)
	var mark := Label.new()
	mark.text = "?"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_override("font", _font(700))
	mark.add_theme_font_size_override("font_size", 46)
	mark.add_theme_color_override("font_color", Color.WHITE)
	icon.add_child(mark)
	return icon


static func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = _font(400)
	t.default_font_size = 24
	t.set_color("font_color", "Label", Color.BLACK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("f4f3ee")
	normal.set_border_width_all(2)
	normal.border_color = Color("003c74")
	normal.set_corner_radius_all(5)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color("f8b33d") # XP's orange hover glow
	hover.set_border_width_all(3)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = Color("7da2ce") # XP's blue focus ring
	focus.set_border_width_all(4)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", hover)
	t.set_stylebox("focus", "Button", focus)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		t.set_color(c, "Button", Color.BLACK)
	return t


static func _font(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Tahoma", "Trebuchet MS", "Noto Sans", "Sans-Serif"])
	f.font_weight = weight
	return f


static func _gradient(colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in colors.size():
		g.add_point(float(i) / (colors.size() - 1), colors[i])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	return tex
