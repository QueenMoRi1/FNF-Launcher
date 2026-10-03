class_name SeasonalExtras
extends RefCounted
## Optional seasonal touches for the built-in skins (Settings > SEASONAL EXTRAS),
## shown when no custom theme is in use:
##   December: snow and a string of twinkling lights   Dec 31 - Jan 2: confetti
##   October: bats and a spooky tint   Feb 10-14: hearts   March 17: green
##   April 1: a small gag
## Preview any of them with the launch option --season=<name>.

const EVENTS := ["christmas", "newyear", "halloween", "valentine", "stpatrick", "aprilfools"]


## Today's event, or "" (a --season=<name> launch option overrides the date).
static func current() -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--season="):
			var s := a.trim_prefix("--season=").to_lower()
			return s if s in EVENTS else ""
	var d := Time.get_date_dict_from_system()
	if (d.month == 12 and d.day == 31) or (d.month == 1 and d.day <= 2):
		return "newyear"
	if d.month == 12 and d.day <= 26:
		return "christmas"
	if d.month == 10:
		return "halloween"
	if d.month == 2 and d.day >= 10 and d.day <= 14:
		return "valentine"
	if d.month == 3 and d.day == 17:
		return "stpatrick"
	if d.month == 4 and d.day == 1:
		return "aprilfools"
	return ""


static func apply(main: Node) -> void:
	var event := current()
	if event == "":
		return
	var view: SkinView = main.view
	match event:
		"christmas":
			_particles(view, "snow", Color(1, 1, 1, 0.9), 1.5)
			var lights := _Lights.new()
			view.add_child(lights)
		"newyear":
			_particles(view, "confetti", Color.WHITE, 1.3)
		"halloween":
			_tint(view, Color(0.35, 0.05, 0.45, 0.22))
			_particles(view, "bats", Color(0.06, 0.03, 0.1), 1.8)
		"valentine":
			_particles(view, "hearts", Color("ff5c8a"), 1.4)
		"stpatrick":
			_tint(view, Color(0.05, 0.5, 0.15, 0.18))
			_particles(view, "petals", Color("3ddc6a"), 1.0)
		"aprilfools":
			if main.version_label:
				main.version_label.text = "v99.0.0 PRO MAX ULTRA"
			main._show_message("APRIL FOOLS. EVERYTHING IS FINE. THE ORANG IS IN CHARGE NOW.", 8.0)


## Above the skin's background and mod art, below the game list.
static func _layer_index(view: SkinView) -> int:
	var above := 0
	for n in view.background_nodes + view.mod_art_nodes:
		above = maxi(above, n.get_index())
	return above + 1


static func _particles(view: SkinView, kind: String, color: Color, amount: float) -> void:
	var p := ThemeParticles.new()
	p.name = "SeasonalParticles"
	p.kind = kind
	p.tint = color
	p.amount = amount * 0.7
	p.modulate.a = 0.85
	view.add_child(p) # on top: falling over the menu, never blocking the mouse


static func _tint(view: SkinView, color: Color) -> void:
	var t := ColorRect.new()
	t.color = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(t)
	view.move_child(t, _layer_index(view))
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## A string of coloured lights draped across the top of the screen, twinkling.
class _Lights extends Control:
	const COLORS := [Color("ff3b3b"), Color("3bff6a"), Color("ffd23b"), Color("3bb8ff")]
	var time := 0.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
		offset_bottom = 60

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var bulbs := int(w / 46.0)
		var pts := PackedVector2Array()
		for i in 120:
			var x := w * i / 119.0
			pts.append(Vector2(x, 10.0 + 14.0 * absf(sin(x / w * PI * 6.0))))
		draw_polyline(pts, Color(0.1, 0.12, 0.1), 2.0, true)
		for i in bulbs:
			var x := (i + 0.5) * w / bulbs
			var y := 10.0 + 14.0 * absf(sin(x / w * PI * 6.0)) + 9.0
			var c: Color = COLORS[i % COLORS.size()]
			var on := 0.55 + 0.45 * sin(time * 3.0 + i * 1.7)
			draw_circle(Vector2(x, y), 14.0, Color(c, 0.18 * on))
			draw_circle(Vector2(x, y), 6.0, Color(c, 0.5 + 0.5 * on))
			draw_rect(Rect2(x - 3.0, y - 10.0, 6.0, 5.0), Color(0.25, 0.25, 0.25))
