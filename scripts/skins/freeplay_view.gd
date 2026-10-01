class_name FreeplayView
extends SkinView
## FNF Freeplay-style vertical list with Alphabet text.

const ASSETS := "res://assets/funkin/"
const ROW_SPACING := 160.0
const ICON_SIZE := 130.0
const DEFAULT_TINT := Color("9271fd")
const ART_BRIGHTNESS := 0.65

var bg: TextureRect
var art: TextureRect
var list_root: Control
var rows: Array[Control] = []
var tint := DEFAULT_TINT


func _build(empty_hint: String) -> void:
	bg = TextureRect.new()
	bg.texture = load(ASSETS + "menuDesat.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = tint
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# GameBanana art replaces the menu art when the selected game has some.
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(ART_BRIGHTNESS, ART_BRIGHTNESS, ART_BRIGHTNESS, 0.0)
	add_child(art)
	art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	list_root = Control.new()
	list_root.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(list_root)
	list_root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for item in items:
		var row := _make_row(item)
		list_root.add_child(row)
		rows.append(row)

	if items.is_empty():
		var empty_box := VBoxContainer.new()
		empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
		empty_box.add_theme_constant_override("separation", 24)
		add_child(empty_box)
		empty_box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var title := Alphabet.make_text("No games found", 64)
		title.alignment = BoxContainer.ALIGNMENT_CENTER
		empty_box.add_child(title)
		var hint := UiKit.add_label(empty_box, empty_hint, 24)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func set_selected(i: int, instant := false) -> void:
	var changed := i != selected
	selected = i
	for r in rows.size():
		rows[r].modulate.a = 1.0 if r == selected else 0.6
		if instant:
			rows[r].position = _row_target(r, rows[r])
	if items.is_empty():
		tint = DEFAULT_TINT
		return
	var item: Dictionary = items[selected]
	tint = item.color
	var tex: Texture2D = item.art
	if tex != art.texture or changed:
		art.texture = tex
		art.modulate.a = 0.0
	var target := 1.0 if tex else 0.0
	create_tween().tween_property(art, "modulate:a", target, 0.0 if instant and not tex else 0.35)


func play_launch(i: int, done: Callable) -> void:
	var row := rows[i]
	var tw := create_tween()
	for n in 10:
		tw.tween_callback(row.set_visible.bind(n % 2 == 1)).set_delay(0.06)
	tw.tween_callback(done)


func sounds() -> Dictionary:
	return {
		"scroll": load(ASSETS + "scrollMenu.ogg"),
		"confirm": load(ASSETS + "confirmMenu.ogg"),
		"cancel": load(ASSETS + "cancelMenu.ogg"),
	}


func _process(delta: float) -> void:
	var t := 1.0 - exp(-delta * 10.0)
	for i in rows.size():
		rows[i].position = rows[i].position.lerp(_row_target(i, rows[i]), t)
	bg.modulate = bg.modulate.lerp(tint, 1.0 - exp(-delta * 4.0))


func _make_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	row.add_child(icon)
	# Shrink long names so they fit next to the icon.
	var title: String = item.entry.name
	var height := minf(70.0, 70.0 * 900.0 / maxf(title.length() * 52.0, 1.0))
	var text := Alphabet.make_text(title, height)
	text.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(text)
	return row


func _row_target(i: int, row: Control) -> Vector2:
	var off := i - selected
	return Vector2(90 + off * 24, size.y * 0.45 + off * ROW_SPACING - row.size.y / 2)
