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
## Title/label highlight color for overlays in this skin.
var accent := UiKit.YELLOW
var items: Array = []
var selected := 0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func build(new_items: Array, new_selected: int, empty_hint: String) -> void:
	items = new_items
	selected = new_selected
	_build(empty_hint)
	set_selected(selected, true)


func set_selected(i: int, _instant := false) -> void:
	selected = i


## GameBanana art finished downloading for item i.
func set_art(i: int, tex: Texture2D) -> void:
	if i >= 0 and i < items.size():
		items[i].art = tex
		if i == selected:
			set_selected(selected, true)


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
