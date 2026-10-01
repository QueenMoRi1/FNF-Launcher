class_name UiKit
extends RefCounted
## Shared theme and modal overlay helpers.

const YELLOW := Color("fdd835")
const PINK := Color("ff4fa3")

## Highlight color of the active skin (titles, labels, progress bar).
static var accent := YELLOW


class Overlay extends ColorRect:
	var box: VBoxContainer
	var focus_target: Control


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/funkin/vcr.ttf")
	t.default_font_size = 24
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_outline_color", "Label", Color.BLACK)

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0, 0, 0, 0.88)
	panel.set_border_width_all(4)
	panel.border_color = Color.WHITE
	panel.set_content_margin_all(28)
	t.set_stylebox("panel", "PanelContainer", panel)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.14, 0.18)
	normal.set_border_width_all(3)
	normal.border_color = Color(0.45, 0.45, 0.5)
	normal.set_content_margin_all(10)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.35, 0.12, 0.3)
	focus.border_color = YELLOW
	for kind in ["Button", "OptionButton", "LineEdit"]:
		t.set_stylebox("normal", kind, normal)
		t.set_stylebox("hover", kind, focus)
		t.set_stylebox("pressed", kind, focus)
		t.set_stylebox("focus", kind, focus)
		t.set_color("font_focus_color", kind, YELLOW)
		t.set_color("font_hover_color", kind, YELLOW)

	var widget := StyleBoxFlat.new()
	widget.bg_color = Color(0, 0, 0, 0.75)
	widget.set_border_width_all(3)
	widget.border_color = Color.WHITE
	widget.set_content_margin_all(12)
	add_widget_style(t, widget)
	return t


## Style for the corner jukebox (NowPlaying uses this theme type variation).
static func add_widget_style(t: Theme, style: StyleBox) -> void:
	t.set_type_variation("NowPlayingPanel", "PanelContainer")
	t.set_stylebox("panel", "NowPlayingPanel", style)


## Full-screen dimmed overlay with a centered bordered panel and a title.
static func make_overlay(parent: Control, title: String, width := 820.0) -> Overlay:
	var root := Overlay.new()
	root.color = Color(0, 0, 0, 0.6)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	root.box = VBoxContainer.new()
	root.box.add_theme_constant_override("separation", 14)
	panel.add_child(root.box)
	var head := add_label(root.box, title, 34, accent)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return root


static func add_label(parent: Control, text: String, size := 22, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


static func add_button(parent: Control, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_press)
	parent.add_child(button)
	return button


static func add_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	return row
