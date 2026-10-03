class_name SkinView
extends Control
## Base for launcher skins. A skin only draws the game list; main.gd owns input,
## overlays and launching.
##
## items: [{path, entry, icon: Texture2D, color: Color, art: Texture2D or null}]

enum Axis { VERTICAL, HORIZONTAL }

## Which d-pad axis moves the selection.
var nav_axis := Axis.VERTICAL
## Put the jukebox widget at the bottom-right instead of the top-right.
var widget_at_bottom := false
## Distance of the jukebox widget from the top edge (when it's at the top).
var widget_top := 16.0
## Title/label highlight color for overlays in this skin.
var accent := UiKit.YELLOW
var items: Array = []
var selected := 0
## Pieces a custom theme can move, scale or hide: id -> Control.
var parts := {}
## The skin's own background layers (hidden when a theme brings its own).
var background_nodes: Array[Control] = []
## Layers showing the selected mod's GameBanana art (a theme can turn them off).
var mod_art_nodes: Array[Control] = []


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func build(new_items: Array, new_selected: int, empty_hint: String) -> void:
	items = new_items
	selected = new_selected
	_build(empty_hint)
	_ignore_mouse(self)
	set_selected(selected, true)


func set_selected(i: int, _instant := false) -> void:
	selected = i


## GameBanana art finished downloading for item i.
func set_art(i: int, tex: Texture2D) -> void:
	if i >= 0 and i < items.size():
		items[i].art = tex
		if i == selected:
			set_selected(selected, true)


## A full-screen container for one movable piece of the skin (see `parts`).
func _group(id: String) -> Control:
	var c := Control.new()
	c.name = id
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.set_meta("group", true)
	add_child(c)
	c.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	parts[id] = c
	return c


## Skins only draw; clicks and taps go to main.gd (which asks item_at()).
static func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = MOUSE_FILTER_IGNORE
		_ignore_mouse(child)


## Index of the game drawn at `pos` (screen coordinates), or -1. Used for taps.
func item_at(_pos: Vector2) -> int:
	return -1


## Skin-specific launch animation; must call `done` when finished.
func play_launch(_i: int, done: Callable) -> void:
	done.call()


func make_theme() -> Theme:
	return UiKit.make_theme()


## {scroll, confirm, cancel} -> AudioStream (null entries are silent)
func sounds() -> Dictionary:
	return {}


func _build(_empty_hint: String) -> void:
	pass
