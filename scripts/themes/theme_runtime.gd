class_name ThemeRuntime
extends RefCounted
## Puts a CustomTheme onto the live menu: background, logo, mod art, and the
## layout (moving, scaling and hiding parts). Layout shifts are stored as a %
## of the screen and applied on top of each part's own position, so a theme
## made on a TV still fits a Steam Deck.

## Friendly names for the editor's part list.
const PART_NAMES := {
	"list": "Game list", "header": "Header", "games": "Game row", "clock": "Clock",
	"tabs": "Blades", "details": "Art & details", "jukebox": "Jukebox",
	"hints": "Hint bar", "version": "Version", "logo": "Theme logo",
}


## Every movable part on screen right now: id -> Control.
static func parts_of(main: Node) -> Dictionary:
	var out := {}
	if main.view:
		out.merge(main.view.parts)
	if main.now_playing:
		out["jukebox"] = main.now_playing
	if main.hint_bar:
		out["hints"] = main.hint_bar
	if main.version_label:
		out["version"] = main.version_label
	if is_instance_valid(main.theme_logo):
		out["logo"] = main.theme_logo
	return out


## Sets up the theme's background and logo (call after the skin is built).
static func apply(t: CustomTheme, main: Node) -> void:
	var view: SkinView = main.view
	if is_instance_valid(main.theme_logo):
		main.theme_logo.queue_free()
		main.theme_logo = null
	CustomTheme.current = t
	_apply_cursor(t)
	_apply_scale(t, main)
	if t == null:
		return
	# Background: the theme's colour / image / video / pattern replaces the skin's.
	var bg_file := t.file("background")
	var pattern := t.file("background pattern")
	var grad := t.colors("background gradient")
	if bg_file != "" or pattern != "" or t.values.get("background color", "") != "" or grad.size() >= 2:
		for n in view.background_nodes:
			n.hide()
		var holder := Control.new()
		holder.name = "ThemeBackground"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(holder)
		view.move_child(holder, 0)
		holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var base := ColorRect.new()
		base.color = t.color("background color", Color.BLACK)
		_fill(holder, base)
		if grad.size() >= 2:
			var g := Gradient.new()
			g.colors = PackedColorArray(grad)
			g.offsets = PackedFloat32Array(range(grad.size()).map(func(i): return float(i) / (grad.size() - 1)))
			var gt := GradientTexture2D.new()
			gt.gradient = g
			gt.fill_from = Vector2(0, 0)
			gt.fill_to = Vector2(0, 1)
			gt.width = 8
			gt.height = 256
			var rect := TextureRect.new()
			rect.texture = gt
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			_fill(holder, rect)
		if bg_file.get_extension().to_lower() == "ogv":
			var video := VideoStreamPlayer.new()
			video.stream = load(bg_file) if bg_file.begins_with("res://") else _video(bg_file)
			video.expand = true
			video.loop = true
			video.volume_db = -80.0
			_fill(holder, video)
			video.play()
		elif bg_file != "":
			var img := Image.load_from_file(bg_file)
			if img:
				var rect := TextureRect.new()
				rect.texture = ImageTexture.create_from_image(img)
				rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				_fill(holder, rect)
		if pattern != "":
			var img := Image.load_from_file(pattern)
			if img:
				# Tiles are small, like wallpaper: "pattern size" px tall (80 by default).
				var tile_h := clampi(int(t.percent("pattern size", 80.0)), 16, 512)
				img.resize(maxi(1, img.get_width() * tile_h / img.get_height()), tile_h, Image.INTERPOLATE_LANCZOS)
				var tile := TextureRect.new()
				tile.texture = ImageTexture.create_from_image(img)
				tile.stretch_mode = TextureRect.STRETCH_TILE
				tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tile.modulate.a = clampf(t.percent("pattern opacity", 35.0) / 100.0, 0.0, 1.0)
				_fill(holder, tile)
		var dim := t.percent("background dim", 0.0)
		if dim > 0.0:
			var shade := ColorRect.new()
			shade.color = Color(0, 0, 0, clampf(dim / 100.0, 0.0, 0.95))
			_fill(holder, shade)
	# Particles drift above the background and the mod art, below everything else.
	var particles := ThemeParticles.from_theme(t)
	if particles:
		particles.name = "ThemeParticles"
		view.add_child(particles)
		var above := 0
		for n in view.background_nodes + view.mod_art_nodes:
			above = maxi(above, n.get_index())
		var holder_node := view.get_node_or_null("ThemeBackground")
		if holder_node:
			above = maxi(above, holder_node.get_index())
		view.move_child(particles, above + 1)
	if not t.mod_art():
		for n in view.mod_art_nodes:
			n.visible = false
			n.set_meta("theme_hidden", true)
	# Logo: top centre by default; move it like any other part.
	var logo_file := t.file("logo")
	if logo_file != "":
		var img := Image.load_from_file(logo_file)
		if img:
			var logo := TextureRect.new()
			logo.name = "ThemeLogo"
			logo.texture = ImageTexture.create_from_image(img)
			logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			main.add_child(logo)
			main.move_child(logo, view.get_index() + 1)
			logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
			logo.offset_left = -180
			logo.offset_right = 180
			logo.offset_top = 16
			logo.offset_bottom = 136
			main.theme_logo = logo


static func _apply_cursor(t: CustomTheme) -> void:
	var path := t.file("cursor") if t else ""
	var img := Image.load_from_file(path) if path != "" else null
	if img:
		if img.get_width() > 128:
			img.resize(128, roundi(img.get_height() * 128.0 / img.get_width()))
		var hot := Vector2.ZERO
		var bits := str(t.values.get("cursor hotspot", "")).split(" ", false)
		if bits.size() >= 2:
			hot = Vector2(bits[0].to_float(), bits[1].to_float())
		Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW, hot)
	else:
		Input.set_custom_mouse_cursor(null)


## UI size: the theme's "ui scale", else the Settings value.
static func _apply_scale(t: CustomTheme, main: Node) -> void:
	var pct: float = main.library.settings.get("ui_scale", 100)
	if t and t.values.get("ui scale", "") != "":
		pct = t.percent("ui scale", pct)
	main.get_tree().root.content_scale_factor = clampf(pct / 100.0, 0.6, 2.0)


static func _fill(holder: Control, node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func _video(path: String) -> VideoStream:
	var v := VideoStreamTheora.new()
	v.file = path
	return v


## Moves, scales and hides parts per the theme (or puts them back with t = null).
static func layout(t: CustomTheme, main: Node) -> void:
	var screen: Vector2 = main.get_viewport_rect().size
	var parts := parts_of(main)
	for id in parts:
		var n: Control = parts[id]
		if not is_instance_valid(n):
			continue
		if not n.has_meta("theme_base"):
			n.set_meta("theme_base", [n.offset_left, n.offset_top, n.offset_right, n.offset_bottom, n.visible])
		var b: Array = n.get_meta("theme_base")
		var m: Array = t.moves.get(id, [0.0, 0.0, 100.0]) if t else [0.0, 0.0, 100.0]
		var dx: float = m[0] / 100.0 * screen.x
		var dy: float = m[1] / 100.0 * screen.y
		n.offset_left = b[0] + dx
		n.offset_top = b[1] + dy
		n.offset_right = b[2] + dx
		n.offset_bottom = b[3] + dy
		n.pivot_offset = Vector2.ZERO
		n.scale = Vector2.ONE * clampf(m[2] / 100.0, 0.2, 4.0)
		n.visible = b[4] and not (t and id in t.hidden)


## Where a part is drawn on screen, for the editor: for full-screen groups,
## the area its visible contents cover.
static func part_rect(n: Control, screen: Rect2) -> Rect2:
	if not n.has_meta("group"):
		return _rect_of(n).intersection(screen)
	var out := Rect2()
	var first := true
	for c in n.get_children():
		if c is Control and c.visible:
			var r := _rect_of(c).intersection(screen)
			if r.has_area():
				out = r if first else out.merge(r)
				first = false
	return out


static func _rect_of(n: Control) -> Rect2:
	var xf := n.get_global_transform()
	return Rect2(xf.origin, n.size * xf.get_scale())
