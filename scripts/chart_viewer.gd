class_name ChartViewer
extends Control
## Full-screen chart viewer: plays a song in full (Inst + Voices) and scrolls
## its chart with every note auto-hit, over a PS3-CD-player-style visualizer.
## Up/down: song. Left/right: seek. Q/W (LB/RB): difficulty. Space/A: pause.

signal closed

const LANE_COLORS := [Color("c24b99"), Color("00ffff"), Color("12fa05"), Color("f9393f")]
const ARROW_ROT := [-PI / 2.0, PI, 0.0, PI / 2.0] # left, down, up, right (arrow points up)
const SCROLL := 0.45 # px per ms at speed 1, same as the game
const STRUM_Y := 100.0
const LANE_GAP := 78.0
const NOTE_SIZE := 60.0
const BANDS := 32
const BUS := "ChartViewer"
const SEEK_SECONDS := 5.0
const KEY_HINTS := "↑↓ SONG   ←→ SEEK   Q/W DIFFICULTY   SPACE PAUSE   ESC BACK"
const PAD_HINTS := "↑↓ SONG   ←→ SEEK   LB/RB DIFFICULTY   A PAUSE   B BACK"
# Secret play mode: hold M for 5 seconds to play BF's side with D F J K.
const PLAY_HINTS := "D F J K  PLAY  (ARROWS WORK TOO)   ESC  STOP PLAYING"
const PLAY_KEYS := [KEY_D, KEY_F, KEY_J, KEY_K]
const PLAY_ARROWS := [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]
const PLAY_KEY_NAMES := ["D", "F", "J", "K"]
const HOLD_M_SECONDS := 5.0
const FNF_ASSETS := "res://assets/funkin/"
const COUNTDOWN := [["introTHREE.ogg", ""], ["introTWO.ogg", "ready.png"], ["introONE.ogg", "set.png"], ["introGO.ogg", "go.png"]]

var songs: Array = [] # [{title, game, path}] from Library.all_songs()
var index := 0
var charts: Array = []
var chart_i := -1
var chart := {}
var inst := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer] = []
var length_s := 0.0
var now_ms := 0.0
var paused := false
var next_note := 0
var flash := [[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0]]
var hold_until := [[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0]]
var side_glow := [0.0, 0.0]
var sparkles: Array = [] # [position, velocity, life, color, size]
var spectrum: AudioEffectSpectrumAnalyzerInstance
var bands := PackedFloat32Array()
var bass := 0.0
var beat := 0.0
var hue := 0.0
var trip := 0.0
var time := 0.0
var cooldown := 0.25
var hold_dir := 0
var hold_time := 0.0
var picker_fade := 0.0
var play: PlayMode = null # the secret play mode, while it's on
var play_started := false # countdown over, song running
var m_held := 0.0
var count_next := 0
var crochet := 500.0
var held := [false, false, false, false]
var popup := ""
var popup_time := 0.0
var results: PanelContainer
var font: Font

var bg: ColorRect
var post: ColorRect
var fx: Control
var stage: Control
var title_label: Label
var info_label: Label
var time_label: Label
var status_label: Label
var hints_label: Label
var picker: VBoxContainer
var load_timer: Timer


func setup(song_list: Array, start: int) -> ChartViewer:
	songs = song_list
	index = start
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	bands.resize(BANDS)
	_make_bus()
	inst.bus = BUS
	add_child(inst)
	inst.finished.connect(_on_song_finished)

	bg = _layer(ColorRect.new())
	bg.material = _shader("res://shaders/ps3_waves.gdshader")
	stage = _layer(Control.new())
	stage.draw.connect(_draw_stage)
	fx = _layer(Control.new())
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = add
	fx.draw.connect(_draw_fx)
	post = _layer(ColorRect.new())
	post.material = _shader("res://shaders/trippy_post.gdshader")

	title_label = _text(40, PRESET_BOTTOM_WIDE, -200, -150)
	info_label = _text(20, PRESET_BOTTOM_WIDE, -148, -120)
	time_label = _text(18, PRESET_BOTTOM_WIDE, -88, -64)
	status_label = _text(24, PRESET_CENTER, 150, 190)
	status_label.offset_left = -400
	status_label.offset_right = 400
	hints_label = _text(16, PRESET_BOTTOM_WIDE, -40, -12)
	hints_label.text = PAD_HINTS if Input.get_connected_joypads().size() > 0 else KEY_HINTS
	if AndroidApps.is_android():
		hints_label.hide()
		_touch_bar()

	picker = VBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	picker.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(picker)
	picker.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	picker.offset_bottom = -220

	load_timer = Timer.new()
	load_timer.one_shot = true
	load_timer.wait_time = 0.35
	load_timer.timeout.connect(_load_song)
	add_child(load_timer)

	font = load(FNF_ASSETS + "vcr.ttf")
	Music.player.stream_paused = true
	_select(index)


func _exit_tree() -> void:
	# Hand the speakers back to the jukebox.
	Music.set_game_running(Music.game_running)


func _make_bus() -> void:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "Master")
		AudioServer.add_bus_effect(i, AudioEffectSpectrumAnalyzer.new())
	spectrum = AudioServer.get_bus_effect_instance(i, 0)


func _layer(node: Control) -> Control:
	node.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(node)
	node.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return node


func _shader(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m


func _text(font_size: int, preset: LayoutPreset, top: float, bottom: float) -> Label:
	var label := UiKit.add_label(self, "", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(preset)
	label.offset_top = top
	label.offset_bottom = bottom
	return label


func _touch_bar() -> void:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	bar.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bar.offset_top = -60
	bar.offset_bottom = -8
	for b in [["✕", _close], ["⏮", _select.bind(-1, true)], ["-5s", _seek.bind(-SEEK_SECONDS)], ["⏯", _toggle_pause],
			["+5s", _seek.bind(SEEK_SECONDS)], ["⏭", _select.bind(1, true)], ["DIFF", _change_difficulty.bind(1)]]:
		var button := UiKit.add_button(bar, b[0], b[1])
		button.focus_mode = FOCUS_NONE
		button.add_theme_font_size_override("font_size", 22)


# --- Songs --------------------------------------------------------------------

## Picks song `i` (or moves by `i` when relative). Loading waits a moment so
## scrolling through the list doesn't load every song on the way.
func _select(i: int, relative := false) -> void:
	index = posmod(index + i if relative else i, songs.size())
	_stop_audio()
	chart = {}
	charts = []
	chart_i = -1
	next_note = 0
	title_label.text = songs[index].title.to_upper()
	info_label.text = songs[index].game
	time_label.text = ""
	status_label.text = "LOADING..."
	_fill_picker()
	load_timer.start()


func _fill_picker() -> void:
	for c in picker.get_children():
		c.queue_free()
	for d in range(-2, 3):
		var song: Dictionary = songs[posmod(index + d, songs.size())]
		var label := UiKit.add_label(picker, song.title.to_upper() + ("   ·   " + song.game if d == 0 else ""),
			34 if d == 0 else 22, UiKit.accent if d == 0 else Color(1, 1, 1, 0.55 - 0.15 * absi(d)))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	picker.modulate.a = 1.0
	picker_fade = 1.6


func _load_song() -> void:
	var song: Dictionary = songs[index]
	charts = Chart.find_charts(song.path)
	chart_i = Chart.default_index(charts)
	_load_chart()
	inst.stream = Music.load_stream(song.path)
	if inst.stream == null:
		status_label.text = "COULDN'T OPEN THIS SONG"
		return
	length_s = inst.stream.get_length()
	for path in Chart.find_voices(song.path):
		var stream := Music.load_stream(path)
		if stream:
			var player := AudioStreamPlayer.new()
			player.bus = BUS
			player.stream = stream
			add_child(player)
			voices.append(player)
	_play_from(0.0)


func _load_chart() -> void:
	var loaded := Chart.load_readable(charts, chart_i, songs[index].path)
	chart = loaded[0]
	chart_i = loaded[1]
	if chart.is_empty():
		status_label.text = "NO CHART FOUND. JUST VIBES" if charts.is_empty() else "COULDN'T READ THIS CHART"
	else:
		status_label.text = ""
	_resync()
	_update_info()


func _update_info() -> void:
	var parts := [songs[index].game]
	if not chart.is_empty():
		parts.append(str(charts[chart_i].label).to_upper() + ("  (%d/%d)" % [chart_i + 1, charts.size()] if charts.size() > 1 else ""))
		parts.append("%d NOTES" % chart.notes.size())
		parts.append("%d BPM" % roundi(Chart.bpm_at(chart.bpms, now_ms)))
	info_label.text = "   ·   ".join(parts)


func _change_difficulty(step: int) -> void:
	if charts.size() < 2:
		return
	chart_i = posmod(chart_i + step, charts.size())
	_load_chart()


func _on_song_finished() -> void:
	if play:
		if results == null:
			_show_results()
		return
	if now_ms > 30000.0:
		Achievements.unlock("full_song")
	_select(1, true)


# --- Playback -----------------------------------------------------------------

func _stop_audio() -> void:
	inst.stop()
	inst.stream = null
	for v in voices:
		v.queue_free()
	voices.clear()
	length_s = 0.0


func _play_from(seconds: float) -> void:
	inst.play(seconds)
	for v in voices:
		v.play(seconds)
	inst.stream_paused = paused
	for v in voices:
		v.stream_paused = paused
	now_ms = seconds * 1000.0
	_resync()


func _seek(seconds: float) -> void:
	if inst.stream == null:
		return
	_play_from(clampf(_audio_pos() + seconds, 0.0, maxf(length_s - 0.5, 0.0)))


func _toggle_pause() -> void:
	paused = not paused
	inst.stream_paused = paused
	for v in voices:
		v.stream_paused = paused


func _audio_pos() -> float:
	return inst.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


## After a seek or chart change: find the next note, clear the strum lights.
func _resync() -> void:
	next_note = 0
	if not chart.is_empty():
		var notes: Array = chart.notes
		var lo := 0
		var hi := notes.size()
		while lo < hi:
			var mid := (lo + hi) / 2
			if notes[mid][0] < now_ms:
				lo = mid + 1
			else:
				hi = mid
		next_note = lo
	for side in 2:
		for d in 4:
			flash[side][d] = 0.0
			hold_until[side][d] = 0.0


func _close() -> void:
	_stop_audio()
	closed.emit()


# --- Loop ---------------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	if not Cheats.active:
		_handle_input(delta)
	if play == null:
		_check_m_hold(delta)

	# Smooth song clock that follows the audio (during the play-mode countdown it
	# just counts up to 0, where the song starts).
	if play and not play_started:
		now_ms += delta * 1000.0
		_countdown()
		if now_ms >= 0.0:
			play_started = true
			_play_from(0.0)
	elif inst.playing and not paused:
		var est := _audio_pos() * 1000.0
		now_ms += delta * 1000.0
		now_ms = est if absf(est - now_ms) > 60.0 else lerpf(now_ms, est, 0.1)

	_hit_notes()
	if play and play_started and results == null:
		if play.check_misses(now_ms) > 0:
			popup = "MISS"
			popup_time = 0.6
		if now_ms > play.last_end + 2000.0:
			_show_results()
	popup_time = maxf(popup_time - delta, 0.0)
	for side in 2:
		side_glow[side] = maxf(side_glow[side] - delta * 2.5, 0.0)
		for d in 4:
			var player_lane: bool = play != null and side == 1
			if player_lane and not held[d]:
				hold_until[1][d] = 0.0 # let go of a sustain: it stops
			if hold_until[side][d] > 0.0 and now_ms < hold_until[side][d]:
				flash[side][d] = 1.0
			else:
				flash[side][d] = maxf(flash[side][d] - delta * 6.0, 0.0)
	_read_spectrum(delta)
	_update_sparkles(delta)

	if not chart.is_empty() and inst.playing and not paused:
		beat = pow(1.0 - fmod(Chart.beat_at(chart.bpms, now_ms), 1.0), 3.0)
	else:
		beat = maxf(beat - delta * 3.0, bass * 0.6)
	hue = fmod(hue + delta * (0.025 + bass * 0.12), 1.0)
	trip = lerpf(trip, clampf((_notes_per_second() - 5.0) / 9.0, 0.0, 1.0), delta * 1.2)
	var size_now := get_viewport_rect().size
	for m: ShaderMaterial in [bg.material, post.material]:
		m.set_shader_parameter("time", time)
		m.set_shader_parameter("bass", bass)
		m.set_shader_parameter("beat", beat)
	bg.material.set_shader_parameter("hue", hue)
	bg.material.set_shader_parameter("trip", trip)
	bg.material.set_shader_parameter("aspect", size_now.x / maxf(size_now.y, 1.0))

	if length_s > 0.0:
		var at := clampf(now_ms / 1000.0, 0.0, length_s)
		time_label.text = "%s / %s%s" % [_fmt(at), _fmt(length_s), "   ·   PAUSED" if paused else ""]
	if picker_fade > 0.0:
		picker_fade -= delta
		picker.modulate.a = clampf(picker_fade / 0.5, 0.0, 1.0)
	stage.queue_redraw()
	fx.queue_redraw()


func _handle_input(delta: float) -> void:
	if cooldown > 0.0:
		cooldown -= delta
		return
	if play:
		return # play mode reads its keys in _input
	if Input.is_action_just_pressed("ui_cancel"):
		_close()
		return
	if Input.is_action_just_pressed("ui_up"):
		_select(-1, true)
	elif Input.is_action_just_pressed("ui_down"):
		_select(1, true)
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("music_pause"):
		_toggle_pause()
	if Input.is_action_just_pressed("music_prev"):
		_change_difficulty(-1)
	elif Input.is_action_just_pressed("music_next"):
		_change_difficulty(1)
	# Seeking repeats while held.
	var dir := int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	if dir != hold_dir:
		hold_dir = dir
		hold_time = 0.0
		if dir != 0:
			_seek(SEEK_SECONDS * dir)
	elif dir != 0:
		hold_time += delta
		if hold_time > 0.4:
			hold_time -= 0.15
			_seek(SEEK_SECONDS * dir)


func _gui_input(event: InputEvent) -> void:
	if play:
		return
	var wheel := event as InputEventMouseButton
	if wheel and wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_select(-1 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else 1, true)


func _hit_notes() -> void:
	if chart.is_empty():
		return
	var notes: Array = chart.notes
	while next_note < notes.size() and notes[next_note][0] <= now_ms:
		var n: Array = notes[next_note]
		next_note += 1
		if now_ms - n[0] > 250.0:
			continue # skipped over by a seek or a hitch
		var side: int = n[1]
		if play and side == 1:
			continue # BF's notes are yours to hit in play mode
		var d: int = n[2]
		flash[side][d] = 1.0
		hold_until[side][d] = maxf(hold_until[side][d], n[0] + n[3])
		side_glow[side] = 1.0
		_burst(_strum_pos(side, d), Color(0.6, 0.6, 0.6) if n[4] else LANE_COLORS[d])


func _notes_per_second() -> float:
	if chart.is_empty():
		return 0.0
	var count := 0
	var i := next_note - 1
	while i >= 0 and count < 40 and chart.notes[i][0] > now_ms - 1000.0:
		count += 1
		i -= 1
	return count


func _read_spectrum(delta: float) -> void:
	if spectrum == null:
		return
	var lo := 40.0
	for i in BANDS:
		var hi := 40.0 * pow(12000.0 / 40.0, float(i + 1) / BANDS)
		var mag := spectrum.get_magnitude_for_frequency_range(lo, hi).length()
		var level := clampf((linear_to_db(maxf(mag, 0.00001)) + 62.0) / 52.0, 0.0, 1.0)
		bands[i] = maxf(level, bands[i] - delta * 2.2)
		lo = hi
	var kick := (bands[0] + bands[1] + bands[2] + bands[3]) / 4.0
	bass = lerpf(bass, kick, delta * 10.0)


func _burst(pos: Vector2, color: Color) -> void:
	for i in 10:
		var angle := randf() * TAU
		sparkles.append([pos, Vector2.from_angle(angle) * randf_range(80.0, 340.0), 1.0, color, randf_range(2.0, 6.0)])
	if sparkles.size() > 600:
		sparkles = sparkles.slice(sparkles.size() - 600)


func _update_sparkles(delta: float) -> void:
	var alive := []
	for s in sparkles:
		s[2] -= delta * 1.6
		if s[2] <= 0.0:
			continue
		s[1] *= 1.0 - delta * 2.0
		s[1].y += 120.0 * delta
		s[0] += s[1] * delta
		alive.append(s)
	sparkles = alive


# --- Drawing --------------------------------------------------------------------

func _side_x(side: int) -> float:
	return stage.size.x * (0.25 if side == 0 else 0.75)


func _strum_pos(side: int, d: int) -> Vector2:
	return Vector2(_side_x(side) + (d - 1.5) * LANE_GAP, STRUM_Y)


func _center() -> Vector2:
	return Vector2(stage.size.x / 2.0, stage.size.y * 0.42)


## Spinning disc, strums, notes and the progress bar (normal blending).
func _draw_stage() -> void:
	var c := _center()
	var radius := 92.0 + bass * 22.0 + beat * 6.0
	# The disc: rainbow grooves and a spinning sheen, like the PS3 CD player.
	stage.draw_circle(c, radius, Color(0.04, 0.04, 0.08, 0.85))
	for k in 7:
		var r := radius * (0.36 + 0.09 * k)
		stage.draw_arc(c, r, 0.0, TAU, 72, Color.from_hsv(fmod(hue + k * 0.09 + time * 0.05, 1.0), 0.55, 1.0, 0.28), 2.5, true)
	for k in 2:
		var a := time * 2.2 + k * PI
		stage.draw_arc(c, radius * 0.7, a, a + 0.9, 24, Color(1, 1, 1, 0.22), radius * 0.5, true)
	stage.draw_circle(c, radius * 0.22, Color(0.02, 0.02, 0.04))
	stage.draw_arc(c, radius * 0.22, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0, true)

	# Strums and notes.
	var speed: float = chart.get("speed", 2.0) * SCROLL
	if play:
		var x0 := _strum_pos(1, 0).x - NOTE_SIZE
		var x1 := _strum_pos(1, 3).x + NOTE_SIZE
		stage.draw_rect(Rect2(x0, 0, x1 - x0, stage.size.y), Color(0, 0, 0, 0.35))
	for side in 2:
		for d in 4:
			var p := _strum_pos(side, d)
			var f: float = flash[side][d]
			_arrow(p, d, NOTE_SIZE * (1.0 + 0.12 * f), LANE_COLORS[d] * Color(1, 1, 1, f) if f > 0.01 else Color(0, 0, 0, 0.25),
				LANE_COLORS[d].lerp(Color.WHITE, 0.6) if f > 0.01 else Color(0.75, 0.75, 0.8, 0.6))
	if not chart.is_empty():
		var notes: Array = chart.notes
		for i in range(maxi(next_note - 60, 0), notes.size()):
			var n: Array = notes[i]
			var head_y: float = STRUM_Y + (n[0] - now_ms) * speed
			if head_y > stage.size.y + NOTE_SIZE:
				break
			var end_ms: float = n[0] + n[3]
			if play and n[1] == 1:
				_draw_player_note(n, play.state.get(i, 0), head_y, end_ms, speed)
				continue
			if end_ms < now_ms or (n[3] <= 0.0 and n[0] <= now_ms):
				continue
			var p := _strum_pos(n[1], n[2])
			var color: Color = Color(0.35, 0.35, 0.38) if n[4] else LANE_COLORS[n[2]]
			if n[3] > 0.0:
				var top := maxf(head_y, STRUM_Y)
				var bottom: float = STRUM_Y + (end_ms - now_ms) * speed
				if bottom > top:
					stage.draw_rect(Rect2(p.x - 9.0, top, 18.0, bottom - top), color * Color(1, 1, 1, 0.6))
			if n[0] > now_ms:
				_arrow(Vector2(p.x, head_y), n[2], NOTE_SIZE, color, Color.WHITE if not n[4] else Color(1, 0.2, 0.2))

	if play:
		_draw_play_hud()

	# Progress bar.
	if length_s > 0.0:
		var w := minf(stage.size.x * 0.5, 640.0)
		var bar := Rect2(stage.size.x / 2.0 - w / 2.0, stage.size.y - 100.0, w, 8.0)
		stage.draw_rect(bar, Color(1, 1, 1, 0.18))
		var filled := bar
		filled.size.x *= clampf(now_ms / 1000.0 / length_s, 0.0, 1.0)
		stage.draw_rect(filled, Color.from_hsv(hue, 0.6, 1.0))


## Spectrum ring, glows and sparkles (added on top, so they glow).
func _draw_fx() -> void:
	var c := _center()
	var radius := 104.0 + bass * 26.0 + beat * 8.0
	var count := BANDS * 2
	for i in count:
		var band: float = bands[i if i < BANDS else count - 1 - i]
		var dir := Vector2.from_angle(float(i) / count * TAU + time * 0.25 - PI / 2.0)
		var color := Color.from_hsv(fmod(hue + float(i) / count, 1.0), 0.75, 1.0, 0.9)
		fx.draw_line(c + dir * radius, c + dir * (radius + 6.0 + band * 130.0), color, 5.0, true)
	for side in 2:
		var g: float = side_glow[side]
		if g > 0.01:
			for k in 4:
				fx.draw_circle(Vector2(_side_x(side), STRUM_Y), 90.0 + k * 45.0, Color.from_hsv(fmod(hue + side * 0.5, 1.0), 0.6, 1.0, 0.05 * g))
	for side in 2:
		for d in 4:
			var f: float = flash[side][d]
			if f > 0.01:
				fx.draw_circle(_strum_pos(side, d), 46.0 * f, LANE_COLORS[d] * Color(1, 1, 1, 0.35 * f))
	for s in sparkles:
		fx.draw_circle(s[0], s[4] * s[2], s[3] * Color(1, 1, 1, s[2]))


## An FNF-style arrow: an up arrow shape rotated per lane.
func _arrow(pos: Vector2, d: int, size: float, fill: Color, outline: Color) -> void:
	draw_arrow(stage, pos, d, size, fill, outline)


## An FNF-style arrow on `canvas`: an up arrow shape rotated per lane.
static func draw_arrow(canvas: CanvasItem, pos: Vector2, d: int, size: float, fill: Color, outline: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, -1), Vector2(1, 0.02), Vector2(0.42, 0.02), Vector2(0.42, 0.95),
		Vector2(-0.42, 0.95), Vector2(-0.42, 0.02), Vector2(-1, 0.02)])
	canvas.draw_set_transform(pos, ARROW_ROT[d], Vector2(size, size) / 2.0)
	if fill.a > 0.0:
		canvas.draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	canvas.draw_polyline(loop, outline, 0.13, true)
	canvas.draw_set_transform(Vector2.ZERO)


# --- Secret play mode (hold M for 5 seconds) ---------------------------------------

func _check_m_hold(delta: float) -> void:
	var can := not AndroidApps.is_android() and not chart.is_empty() and inst.stream != null and cooldown <= 0.0
	if can and Input.is_physical_key_pressed(KEY_M):
		m_held += delta
	else:
		m_held = 0.0
	# A growing shake from 1.5 s on, as a hint that something's coming.
	var shake := clampf((m_held - 1.5) / (HOLD_M_SECONDS - 1.5), 0.0, 1.0)
	stage.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 7.0 * shake
	if m_held >= HOLD_M_SECONDS:
		m_held = 0.0
		stage.position = Vector2.ZERO
		_start_play()


## The song restarts with FNF's countdown and you play BF's side.
func _start_play() -> void:
	var p := PlayMode.new(chart.notes)
	if p.is_empty():
		status_label.text = "NO NOTES ON BF'S SIDE IN THIS CHART"
		return
	play = p
	play_started = false
	count_next = 0
	results = null
	held = [false, false, false, false]
	Achievements.unlock("jukebox_game")
	paused = false
	inst.stop()
	for v in voices:
		v.stop()
	crochet = 60000.0 / maxf(Chart.bpm_at(chart.bpms, 0.0), 1.0)
	now_ms = -crochet * 4.6
	_resync()
	picker_fade = 0.0
	picker.modulate.a = 0.0
	status_label.text = ""
	hints_label.text = PLAY_HINTS


func _countdown() -> void:
	# THREE, TWO (ready), ONE (set), GO: one per beat, ending a beat before the song.
	while count_next < 4 and now_ms >= -crochet * (4 - count_next):
		var step: Array = COUNTDOWN[count_next]
		count_next += 1
		var sound := AudioStreamPlayer.new()
		sound.stream = load(FNF_ASSETS + step[0])
		add_child(sound)
		sound.finished.connect(sound.queue_free)
		sound.play()
		if step[1] == "":
			continue
		var tex: Texture2D = load(FNF_ASSETS + step[1])
		if tex == null:
			continue
		var img := TextureRect.new()
		img.texture = tex
		img.mouse_filter = MOUSE_FILTER_IGNORE
		img.size = tex.get_size() * 0.6
		img.pivot_offset = img.size / 2.0
		img.position = Vector2(stage.size.x / 2.0, stage.size.y * 0.42) - img.size / 2.0
		img.scale = Vector2(1.1, 1.1)
		add_child(img)
		var tw := img.create_tween()
		tw.tween_property(img, "scale", Vector2.ONE, crochet / 1000.0 * 0.4)
		tw.parallel().tween_property(img, "modulate:a", 0.0, crochet / 1000.0).set_ease(Tween.EASE_IN)
		tw.tween_callback(img.queue_free)


func _input(event: InputEvent) -> void:
	if play == null:
		return
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	if key.pressed and (key.keycode == KEY_ESCAPE or (results and key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])):
		get_viewport().set_input_as_handled()
		_end_play()
		return
	var lane := PLAY_KEYS.find(key.physical_keycode)
	if lane < 0:
		lane = PLAY_ARROWS.find(key.physical_keycode)
	if lane < 0:
		return
	get_viewport().set_input_as_handled()
	held[lane] = key.pressed
	if key.pressed and play_started and results == null:
		_player_press(lane)


func _player_press(lane: int) -> void:
	var t := _audio_pos() * 1000.0 if inst.playing else now_ms
	flash[1][lane] = maxf(flash[1][lane], 0.35)
	var hit := play.press(lane, t)
	if hit[1] < 0:
		return
	var n: Array = chart.notes[hit[1]]
	popup = hit[0]
	popup_time = 0.6
	flash[1][lane] = 1.0
	side_glow[1] = 1.0
	if n[3] > 0.0:
		hold_until[1][lane] = n[0] + n[3]
	_burst(_strum_pos(1, lane), LANE_COLORS[lane])


func _show_results() -> void:
	play.finish()
	var center := CenterContainer.new()
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	results = PanelContainer.new()
	center.add_child(results)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	results.add_child(box)
	for line in [["SONG CLEARED!", 40, UiKit.accent], [songs[index].title.to_upper(), 24, Color.WHITE], [play.rank(), 52, UiKit.accent],
			["SCORE  %s" % PlayMode.commas(play.score), 26, Color.WHITE], ["ACCURACY  %.2f%%" % play.accuracy(), 22, Color.WHITE],
			["MISSES  %d     MAX COMBO  %d" % [play.misses, play.max_combo], 22, Color.WHITE], ["PRESS ENTER", 18, Color(1, 1, 1, 0.7)]]:
		var l := UiKit.add_label(box, line[0], line[1], line[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	results.modulate.a = 0.0
	results.create_tween().tween_property(results, "modulate:a", 1.0, 0.25)


## Back to watching: the rest of the song, or the next one if it ended.
func _end_play() -> void:
	var song_over := results != null and not inst.playing
	if results:
		results.get_parent().queue_free() # its CenterContainer
		results = null
	play = null
	play_started = false
	held = [false, false, false, false]
	popup_time = 0.0
	cooldown = 0.3 # the Esc that ended it mustn't also close the viewer
	hints_label.text = PAD_HINTS if Input.get_connected_joypads().size() > 0 else KEY_HINTS
	if song_over:
		_select(1, true)
	elif not inst.playing:
		_play_from(0.0)
	_resync()


func _draw_player_note(n: Array, st: int, head_y: float, end_ms: float, speed: float) -> void:
	var p := _strum_pos(1, n[2])
	var color: Color = Color(0.35, 0.35, 0.38) if n[4] else LANE_COLORS[n[2]]
	var alpha := 0.3 if st == 2 else 1.0
	var tail: bool = n[3] > 0.0 and end_ms > now_ms
	if st == 1:
		# Hit: only a sustain you're still holding stays, draining at the strum.
		if tail and held[n[2]] and hold_until[1][n[2]] >= end_ms - 1.0:
			var bottom: float = STRUM_Y + (end_ms - now_ms) * speed
			stage.draw_rect(Rect2(p.x - 9.0, STRUM_Y, 18.0, bottom - STRUM_Y), color * Color(1, 1, 1, 0.6))
		return
	if head_y < -NOTE_SIZE and not tail:
		return
	if tail:
		var bottom: float = STRUM_Y + (end_ms - now_ms) * speed
		if bottom > head_y:
			stage.draw_rect(Rect2(p.x - 9.0, head_y, 18.0, bottom - head_y), color * Color(1, 1, 1, 0.6 * alpha))
	if head_y > -NOTE_SIZE:
		_arrow(Vector2(p.x, head_y), n[2], NOTE_SIZE, color * Color(1, 1, 1, alpha), Color(1, 1, 1, alpha) if not n[4] else Color(1, 0.2, 0.2, alpha))


func _draw_play_hud() -> void:
	var x0 := _strum_pos(1, 0).x - NOTE_SIZE
	var w := _strum_pos(1, 3).x + NOTE_SIZE - x0
	# The keys, shown during the countdown.
	var key_alpha := clampf(1.0 - (now_ms + 400.0) / 900.0, 0.0, 1.0)
	if key_alpha > 0.0:
		for lane in 4:
			var r := Rect2(_strum_pos(1, lane).x - 26.0, STRUM_Y + 50.0, 52.0, 52.0)
			stage.draw_rect(r, Color(1, 1, 1, 0.92 * key_alpha))
			stage.draw_rect(r, Color(0, 0, 0, key_alpha), false, 3.0)
			stage.draw_string(font, Vector2(r.position.x, r.position.y + 39.0), PLAY_KEY_NAMES[lane], HORIZONTAL_ALIGNMENT_CENTER, 52.0, 36, Color(0, 0, 0, key_alpha))
		stage.draw_string_outline(font, Vector2(x0, STRUM_Y + 140.0), "PRESS THEM ON BEAT", HORIZONTAL_ALIGNMENT_CENTER, w, 20, 6, Color(0, 0, 0, key_alpha))
		stage.draw_string(font, Vector2(x0, STRUM_Y + 140.0), "PRESS THEM ON BEAT", HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(1, 1, 1, key_alpha))
	# Rating and combo.
	if popup_time > 0.0:
		var a := clampf(popup_time / 0.3, 0.0, 1.0)
		var c := Color(1, 0.35, 0.35, a) if popup == "MISS" else Color(UiKit.accent, a)
		var y := stage.size.y * 0.45 - (0.6 - popup_time) * 40.0
		stage.draw_string_outline(font, Vector2(x0, y), popup, HORIZONTAL_ALIGNMENT_CENTER, w, 44, 10, Color(0, 0, 0, a))
		stage.draw_string(font, Vector2(x0, y), popup, HORIZONTAL_ALIGNMENT_CENTER, w, 44, c)
		if play.combo >= 2:
			stage.draw_string_outline(font, Vector2(x0, y + 46.0), str(play.combo), HORIZONTAL_ALIGNMENT_CENTER, w, 34, 8, Color(0, 0, 0, a))
			stage.draw_string(font, Vector2(x0, y + 46.0), str(play.combo), HORIZONTAL_ALIGNMENT_CENTER, w, 34, Color(1, 1, 1, a))
	# Score line, top centre.
	var hud := "SCORE %s   ·   MISSES %d   ·   %.1f%%" % [PlayMode.commas(play.score), play.misses, play.accuracy()]
	stage.draw_string_outline(font, Vector2(0, 34.0), hud, HORIZONTAL_ALIGNMENT_CENTER, stage.size.x, 24, 8, Color.BLACK)
	stage.draw_string(font, Vector2(0, 34.0), hud, HORIZONTAL_ALIGNMENT_CENTER, stage.size.x, 24, Color.WHITE)


static func _fmt(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
