class_name ThemeParticles
extends Control
## Animated background for custom themes: things drifting across the menu.
##   particles: snow | bubbles | notes | stars | confetti | leaves | petals |
##              bats | hearts | rain | embers | fireflies
##   particles color: #ffffff (or "rainbow")   particles amount / speed / size: 100%

const KINDS := ["snow", "bubbles", "notes", "stars", "confetti", "leaves", "petals", "bats", "hearts", "rain", "embers", "fireflies"]
## Per kind: [count at 100%, base speed px/s (+ = down), drift, base size]
const SPECS := {
	"snow": [90, 40.0, 25.0, 4.0], "bubbles": [40, -45.0, 18.0, 12.0], "notes": [26, -35.0, 12.0, 22.0],
	"stars": [70, 0.0, 0.0, 3.0], "confetti": [70, 70.0, 35.0, 7.0], "leaves": [32, 45.0, 45.0, 11.0],
	"petals": [45, 38.0, 40.0, 7.0], "bats": [14, -25.0, 60.0, 16.0], "hearts": [30, -40.0, 20.0, 11.0],
	"rain": [130, 520.0, 30.0, 18.0], "embers": [60, -60.0, 20.0, 3.0], "fireflies": [36, 0.0, 22.0, 3.5],
}
const RAINBOW := [Color("ff4f6d"), Color("ffb84f"), Color("fff36b"), Color("6bff8f"), Color("4fc3ff"), Color("b56bff")]

var kind := "snow"
var tint := Color.WHITE
var rainbow := false
var amount := 1.0
var speed := 1.0
var scale_size := 1.0
var parts: Array = [] # [pos, vel, size, phase, color, spin]
var time := 0.0


static func from_theme(t: CustomTheme) -> ThemeParticles:
	var k := str(t.values.get("particles", "")).to_lower().strip_edges()
	if not k in KINDS:
		return null
	var p := ThemeParticles.new()
	p.kind = k
	var c := str(t.values.get("particles color", "")).to_lower().strip_edges()
	p.rainbow = c == "rainbow"
	p.tint = t.color("particles color", _default_color(k))
	p.amount = clampf(t.percent("particles amount", 100.0) / 100.0, 0.0, 3.0)
	p.speed = clampf(t.percent("particles speed", 100.0) / 100.0, 0.1, 4.0)
	p.scale_size = clampf(t.percent("particles size", 100.0) / 100.0, 0.3, 4.0)
	return p


static func _default_color(k: String) -> Color:
	match k:
		"bubbles":
			return Color(0.7, 0.9, 1.0, 0.6)
		"leaves":
			return Color("e07b2a")
		"petals":
			return Color("ffb7d2")
		"bats":
			return Color(0.08, 0.05, 0.12)
		"hearts":
			return Color("ff5c8a")
		"rain":
			return Color(0.7, 0.8, 1.0, 0.55)
		"embers":
			return Color("ff8a2a")
		"fireflies":
			return Color("e8ff6b")
		"notes":
			return Color(1, 1, 1, 0.8)
	return Color.WHITE


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_spawn_all.call_deferred()


func _spawn_all() -> void:
	parts.clear()
	var n := int(SPECS[kind][0] * amount)
	for i in n:
		parts.append(_new_part(true))


func _new_part(anywhere: bool) -> Array:
	var spec: Array = SPECS[kind]
	var w := maxf(size.x, 1.0)
	var h := maxf(size.y, 1.0)
	var down: bool = spec[1] >= 0.0
	var y := randf_range(0.0, h) if anywhere or spec[1] == 0.0 else (-20.0 if down else h + 20.0)
	var vy: float = spec[1] * speed * randf_range(0.7, 1.3)
	var col := tint
	if rainbow or kind == "confetti" and tint == Color.WHITE:
		col = RAINBOW[randi() % RAINBOW.size()]
	var sz: float = spec[3] * scale_size * randf_range(0.6, 1.4)
	return [Vector2(randf_range(0.0, w), y), Vector2(randf_range(-0.3, 0.3) * spec[2] * speed, vy), sz, randf() * TAU, col, randf_range(-2.0, 2.0)]


func _process(delta: float) -> void:
	time += delta
	if parts.is_empty() and amount > 0.0 and size.x > 1.0:
		_spawn_all()
	var spec: Array = SPECS[kind]
	for i in parts.size():
		var p: Array = parts[i]
		var sway: float = sin(time * 1.3 + p[3]) * spec[2] * speed
		p[0] += Vector2(p[1].x + sway * 0.5, p[1].y) * delta
		p[3] += delta * p[5]
		var off: bool = p[0].y > size.y + 30.0 or p[0].y < -30.0 or p[0].x < -40.0 or p[0].x > size.x + 40.0
		if off:
			parts[i] = _new_part(false)
	queue_redraw()


func _draw() -> void:
	for p in parts:
		var pos: Vector2 = p[0]
		var s: float = p[2]
		var c: Color = p[4]
		match kind:
			"snow":
				draw_circle(pos, s * 0.5, c)
			"bubbles":
				draw_arc(pos, s * 0.5, 0.0, TAU, 20, c, 1.5, true)
				draw_circle(pos + Vector2(-s * 0.15, -s * 0.15), s * 0.1, Color(1, 1, 1, c.a))
			"notes":
				ChartViewer.draw_arrow(self, pos, int(absf(p[3] * 10.0)) % 4, s, Color(ChartViewer.LANE_COLORS[int(absf(p[3] * 10.0)) % 4], c.a * 0.85), Color(1, 1, 1, c.a))
			"stars":
				var twinkle := 0.5 + 0.5 * sin(time * 2.5 + p[3] * 7.0)
				_star(pos, s * (0.8 + twinkle * 0.6), Color(c, c.a * (0.35 + 0.65 * twinkle)))
			"confetti":
				draw_set_transform(pos, p[3], Vector2.ONE)
				draw_rect(Rect2(-s * 0.5, -s * 0.25, s, s * 0.5), c)
				draw_set_transform(Vector2.ZERO)
			"leaves", "petals":
				draw_set_transform(pos, p[3], Vector2(1.0, 0.55))
				draw_circle(Vector2.ZERO, s * 0.5, c)
				draw_set_transform(Vector2.ZERO)
			"bats":
				_bat(pos, s, c, sin(time * 12.0 + p[3]))
			"hearts":
				_heart(pos, s, c)
			"rain":
				draw_line(pos, pos + Vector2(p[1].x, p[1].y).normalized() * s, c, 1.5, true)
			"embers", "fireflies":
				var glow := 0.5 + 0.5 * sin(time * (6.0 if kind == "embers" else 2.0) + p[3] * 5.0)
				draw_circle(pos, s * 2.2, Color(c, 0.12 * glow))
				draw_circle(pos, s * 0.6, Color(c, 0.5 + 0.5 * glow))


func _star(pos: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0
		pts.append(pos + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.35))
	draw_colored_polygon(pts, c)


func _heart(pos: Vector2, s: float, c: Color) -> void:
	var r := s * 0.3
	draw_circle(pos + Vector2(-r, -r * 0.3), r, c)
	draw_circle(pos + Vector2(r, -r * 0.3), r, c)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-s * 0.58, -r * 0.1), pos + Vector2(s * 0.58, -r * 0.1), pos + Vector2(0, s * 0.62)]), c)


## A simple bat silhouette: a body with two zig-zag wings that flap.
func _bat(pos: Vector2, s: float, c: Color, flap: float) -> void:
	var lift := flap * s * 0.35
	var cols := PackedColorArray([c, c, c])
	for side in [-1.0, 1.0]:
		var top := pos + Vector2(side * s * 0.45, -s * 0.25 - lift)
		var tip := pos + Vector2(side * s, -s * 0.05 - lift)
		# Triangles drawn directly, so a flapping wing can never be an "invalid polygon".
		for tri in [[pos, top, pos + Vector2(side * s * 0.25, s * 0.15)], [top, tip, pos + Vector2(side * s * 0.5, s * 0.02)],
				[tip, pos + Vector2(side * s * 0.75, s * 0.1), pos + Vector2(side * s * 0.5, s * 0.02)], [pos, top, pos + Vector2(side * s * 0.5, s * 0.02)]]:
			draw_primitive(PackedVector2Array(tri), cols, PackedVector2Array())
	draw_circle(pos, s * 0.18, c)
