class_name Wrapped
extends UiKit.Overlay
## Funkin' Wrapped: a slideshow of your year in FNF mods (Settings > FUN STUFF).
## → / Enter / click: next card. ←: back. S: save the card as an image. Esc: close.

const CARD_COLORS := [["1b1035", "ff4f8a"], ["0d2a4a", "31b0d1"], ["3a0a24", "ff8a1f"], ["06281a", "3ddc6a"],
	["2a1048", "b56bff"], ["3a2a00", "ffd23f"], ["1a1a1a", "ff4f6d"]]

var main: Node
var cards: Array = [] # [{title, lines: [[text, size]], art: Texture2D}]
var index := 0
var card: Control
var bg: TextureRect
var font: Font
var busy := false


static func open(m: Node) -> void:
	var w := Wrapped.new()
	w.main = m
	m.add_child(w)
	w.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	m._open_overlay(w)
	Achievements.unlock("wrapped")


func _ready() -> void:
	color = Color.BLACK
	mouse_filter = MOUSE_FILTER_STOP
	font = UiKit.make_theme().default_font
	bg = TextureRect.new()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var confetti := ThemeParticles.new()
	confetti.kind = "confetti"
	confetti.amount = 0.6
	add_child(confetti)
	var hint := _label("→ next   ← back   S save image   Esc close", 16, Color(1, 1, 1, 0.6))
	hint.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_cards()
	_show(0, 0)
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_step(1))


func _label(text: String, size: int, c := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(l)
	return l


static func hours(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	if h == 0:
		return "%d minute%s" % [m, "" if m == 1 else "s"]
	return "%d hour%s %d min" % [h, "" if h == 1 else "s", m]


func _art_for(slug: String) -> Texture2D:
	for path in main.library.games:
		if main.library.games[path].get("slug", "") == slug:
			return main.arts.get(path)
	return null


func _build_cards() -> void:
	var y: int = Time.get_date_dict_from_system().year
	var s := Stats.year(y)
	var month: int = Time.get_date_dict_from_system().month
	cards.append({"title": "FUNKIN' WRAPPED %d" % y, "lines": [
		["your year in FNF mods" + ("" if month == 12 else ", so far"), 30],
		["(press → )", 20]]})
	if s.seconds < 60 and s.songs.is_empty():
		cards.append({"title": "NOT MUCH YET", "lines": [["Play some mods (and let the jukebox run) and come back.", 28],
			["The launcher starts counting from v1.7.0.", 20]]})
	else:
		cards.append({"title": "YOU FUNKED FOR", "lines": [[hours(s.seconds), 64], ["across %d session%s on %d day%s" % [s.sessions, "" if s.sessions == 1 else "s", s.days, "" if s.days == 1 else "s"], 26]]})
		if not s.mods.is_empty():
			var top: Dictionary = s.mods[0]
			var slug := ""
			for sess in Stats.data().sessions:
				if sess[3] == top.name:
					slug = sess[2]
			cards.append({"title": "YOUR #1 MOD", "lines": [[top.name, 46], ["%s · %d session%s" % [hours(top.seconds), top.sessions, "" if top.sessions == 1 else "s"], 26]], "art": _art_for(slug)})
		if s.mods.size() > 1:
			var lines := []
			for i in mini(5, s.mods.size()):
				lines.append(["%d.  %s   %s" % [i + 1, s.mods[i].name, hours(s.mods[i].seconds)], 26])
			cards.append({"title": "TOP MODS", "lines": lines})
		if not s.songs.is_empty():
			var lines := []
			for i in mini(5, s.songs.size()):
				lines.append(["%d.  %s  (%s)  ×%d" % [i + 1, s.songs[i].title, s.songs[i].game, s.songs[i].count], 22])
			cards.append({"title": "ON REPEAT IN THE JUKEBOX", "lines": lines})
		var facts := []
		if s.longest[0] > 0:
			facts.append(["Longest session: %s of %s" % [hours(s.longest[0]), s.longest[1]], 24])
		if s.late_night > 0:
			facts.append(["%d session%s between midnight and 4 AM. go to bed." % [s.late_night, "" if s.late_night == 1 else "s"], 24])
		var got := 0
		for id in Achievements.data.unlocked:
			if Time.get_datetime_dict_from_unix_time(int(Achievements.data.unlocked[id])).year == y:
				got += 1
		if got > 0:
			facts.append(["%d achievement%s unlocked" % [got, "" if got == 1 else "s"], 24])
		var best := PlayScores.best_run()
		if not best.is_empty():
			facts.append(["Best play mode run: %s on %s (%s)" % [best.rank, best.title, PlayMode.commas(best.score)], 24])
		if not facts.is_empty():
			cards.append({"title": "FUN FACTS", "lines": facts})
	cards.append({"title": "THANKS FOR FUNKIN'", "lines": [["see you next year.", 30], ["– orang entertainment 🍊", 22]]})


func _show(i: int, dir: int) -> void:
	index = clampi(i, 0, cards.size() - 1)
	var c: Array = CARD_COLORS[index % CARD_COLORS.size()]
	var grad := Gradient.new()
	grad.set_color(0, Color(c[0]))
	grad.set_color(1, Color(c[1]))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 1)
	bg.texture = gt
	var old := card
	card = VBoxContainer.new()
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 18)
	card.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(card)
	card.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	card.offset_left = 80
	card.offset_right = -80
	card.offset_bottom = -50
	var data: Dictionary = cards[index]
	var art: Texture2D = data.get("art")
	if art:
		var pic := TextureRect.new()
		pic.texture = art
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(0, size.y * 0.32)
		card.add_child(pic)
	var title := _label(data.title, 54, Color.WHITE)
	remove_child(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	for line in data.lines:
		var l := _label(line[0], line[1])
		remove_child(l)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(l)
	var count := _label("%d / %d" % [index + 1, cards.size()], 16, Color(1, 1, 1, 0.5))
	remove_child(count)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(count)
	card.modulate.a = 0.0
	card.position.x = 60.0 * dir
	var tw := card.create_tween().set_parallel()
	tw.tween_property(card, "modulate:a", 1.0, 0.3)
	tw.tween_property(card, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if old:
		old.queue_free()


func _step(dir: int) -> void:
	if index + dir >= cards.size():
		main._close_overlay()
		return
	if index + dir < 0:
		return
	_show(index + dir, dir)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		match k.keycode:
			KEY_RIGHT, KEY_ENTER, KEY_SPACE, KEY_KP_ENTER:
				_step(1)
			KEY_LEFT:
				_step(-1)
			KEY_S:
				save_image()
			KEY_ESCAPE:
				main._close_overlay()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	var b := event as InputEventJoypadButton
	if b and b.pressed:
		match b.button_index:
			JOY_BUTTON_A, JOY_BUTTON_DPAD_RIGHT:
				_step(1)
			JOY_BUTTON_DPAD_LEFT:
				_step(-1)
			JOY_BUTTON_B:
				main._close_overlay()
			JOY_BUTTON_X:
				save_image()
			_:
				return
		get_viewport().set_input_as_handled()


## Saves the current card to Pictures/ as a PNG.
func save_image() -> void:
	if busy:
		return
	busy = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics == "":
		pics = OS.get_environment("HOME")
	var path := pics.path_join("FNF Wrapped %d - %d.png" % [Time.get_date_dict_from_system().year, index + 1])
	img.save_png(path)
	main._show_message("SAVED TO " + path.to_upper(), 5.0)
	busy = false
