class_name Chromatics
extends Control
## Easter egg: type "chromatics". A piano you play with the keyboard, sung by
## Boyfriend, who poses along. His voice is a real note from FunkinCrew's
## Tutorial vocals, pitched per key (the way chromatic scales are made). BF's
## sprite sheet and that vocal track are downloaded from FunkinCrew the first
## time and cached; they aren't ours to ship.
##
## Another chromatic: put one sung note (.ogg or .wav) in res://assets/chromatics/
## (shipped with the launcher) or in the "chromatics" folder next to "themes"
## (a player's own; it wins). Optionally add chromatic.txt beside it:
##   note: C4      start: 0.0      length: 0.4
##   credit: Chromatic by <creator> (link)      shown on screen while you play

signal closed

const RAW := "https://raw.githubusercontent.com/FunkinCrew/Funkin.assets/main/"
const FILES := {
	"BOYFRIEND.png": "shared/images/characters/BOYFRIEND.png",
	"BOYFRIEND.xml": "shared/images/characters/BOYFRIEND.xml",
	"Voices-bf.ogg": "songs/tutorial/Voices-bf.ogg",
}
## BF's "beep" on C4 in Tutorial's vocals.
const SAMPLE_START := 15.6
const SAMPLE_LENGTH := 0.32
const SAMPLE_NOTE := 60
## Two octaves, FL Studio style: the bottom rows play C3-B3, the top rows C4-C5.
const LOW_KEYS := [KEY_Z, KEY_S, KEY_X, KEY_D, KEY_C, KEY_V, KEY_G, KEY_B, KEY_H, KEY_N, KEY_J, KEY_M]
const HIGH_KEYS := [KEY_Q, KEY_2, KEY_W, KEY_3, KEY_E, KEY_R, KEY_5, KEY_T, KEY_6, KEY_Y, KEY_7, KEY_U, KEY_I]
const FIRST_NOTE := 48 # C3
const NOTE_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const POSES := ["BF NOTE LEFT", "BF NOTE DOWN", "BF NOTE UP", "BF NOTE RIGHT"]
const ROLL_SPEED := 180.0 # px per second the played notes scroll up

var font: Font
var sample: AudioStream
var sample_start := SAMPLE_START
var sample_length := SAMPLE_LENGTH
var sample_note := SAMPLE_NOTE
var custom_name := ""
var credit := ""
var bf: AnimatedSprite2D
var bf_box: Control
var keyboard: Control
var roll: Control
var status: Label
var help: Label
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var held := {} # note -> true while its key is down
var trails: Array = [] # [note, y_start_age, length or -1 while held]
var pose_time := 0.0
var ready_to_play := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	font = UiKit.make_theme().default_font
	var bg := ColorRect.new()
	bg.color = Color("0d0a1a")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	roll = Control.new()
	roll.draw.connect(_draw_roll)
	add_child(roll)
	roll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bf_box = Control.new()
	add_child(bf_box)
	keyboard = Control.new()
	keyboard.draw.connect(_draw_keyboard)
	add_child(keyboard)
	var title := _label("CHROMATICS", 40, Color("31b0d1"))
	title.position = Vector2(30, 20)
	status = _label("", 18, Color(1, 1, 1, 0.7))
	status.position = Vector2(30, 70)
	help = _label("Z-M: low octave   Q-I: high octave   SPACE: hey!   ESC: back", 18, Color(1, 1, 1, 0.55))
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		voices.append(p)
	resized.connect(_layout)
	_layout()
	Music.player.stream_paused = true
	_load_assets()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(l)
	return l


static func cache_dir() -> String:
	return Library.prefixes_dir().get_base_dir().path_join("cache/chromatics")


static func custom_dir() -> String:
	return Library.prefixes_dir().get_base_dir().path_join("chromatics")


# --- Assets -------------------------------------------------------------------------

func _load_assets() -> void:
	DirAccess.make_dir_recursive_absolute(cache_dir())
	DirAccess.make_dir_recursive_absolute(custom_dir())
	for f in FILES:
		var path := cache_dir().path_join(f)
		if FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path).size() > 0:
			continue
		status.text = "Fetching Boyfriend from FunkinCrew..."
		var http := HTTPRequest.new()
		http.download_file = path + ".part"
		add_child(http)
		http.request(RAW + FILES[f])
		var r: Array = await http.request_completed
		http.queue_free()
		if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
			DirAccess.remove_absolute(path + ".part")
			status.text = "Couldn't download Boyfriend (no internet?). Press ESC."
			return
		DirAccess.rename_absolute(path + ".part", path)
	_build_bf()
	_load_voice()
	status.text = ("Voice: " + custom_name) if custom_name != "" else "Voice: Boyfriend (FNF Tutorial, FunkinCrew)"
	if credit != "":
		var c := _label(credit, 18, Color(1, 1, 1, 0.75))
		c.position = Vector2(30, 96)
	ready_to_play = true


const BUNDLED := "res://assets/chromatics"


func _load_voice() -> void:
	for dir in [custom_dir(), BUNDLED]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			var ext := f.get_extension().to_lower()
			var stream: AudioStream = null
			if dir == BUNDLED and ext in ["ogg", "wav"]:
				stream = load(dir.path_join(f))
			elif ext == "ogg":
				stream = AudioStreamOggVorbis.load_from_file(dir.path_join(f))
			elif ext == "wav":
				stream = AudioStreamWAV.load_from_file(dir.path_join(f))
			if stream:
				sample = stream
				custom_name = f.get_basename()
				sample_start = 0.0
				sample_length = minf(stream.get_length(), 1.5)
				sample_note = SAMPLE_NOTE
				_read_custom_settings(dir)
				return
	sample = AudioStreamOggVorbis.load_from_file(cache_dir().path_join("Voices-bf.ogg"))


func _read_custom_settings(dir: String) -> void:
	var txt := dir.path_join("chromatic.txt")
	if not FileAccess.file_exists(txt):
		return
	for line in FileAccess.get_file_as_string(txt).split("\n"):
		var kv := line.split(":", true, 1)
		if kv.size() != 2:
			continue
		var v := kv[1].strip_edges()
		match kv[0].strip_edges().to_lower():
			"note":
				sample_note = note_number(v, SAMPLE_NOTE)
			"start":
				sample_start = maxf(v.to_float(), 0.0)
			"length":
				sample_length = clampf(v.to_float(), 0.05, 5.0)
			"credit":
				credit = v


## "C4", "F#3", "Bb2" -> a MIDI note number.
static func note_number(text: String, fallback: int) -> int:
	var t := text.strip_edges().to_upper()
	var m := RegEx.create_from_string("^([A-G])([#B]?)(-?\\d)$").search(t)
	if m == null:
		return fallback
	var n: int = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}[m.get_string(1)]
	n += 1 if m.get_string(2) == "#" else (-1 if m.get_string(2) == "B" else 0)
	return (int(m.get_string(3)) + 1) * 12 + n


## BF's classic Sparrow sheet -> SpriteFrames (one animation per frame prefix).
func _build_bf() -> void:
	var img := Image.load_from_file(cache_dir().path_join("BOYFRIEND.png"))
	if img == null:
		return
	var tex := ImageTexture.create_from_image(img)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var xml := XMLParser.new()
	if xml.open(cache_dir().path_join("BOYFRIEND.xml")) != OK:
		return
	var wanted := ["BF idle dance", "BF HEY!!"] + POSES
	while xml.read() == OK:
		if xml.get_node_type() != XMLParser.NODE_ELEMENT or xml.get_node_name() != "SubTexture":
			continue
		var name := xml.get_named_attribute_value_safe("name")
		var anim := name.left(name.length() - 4)
		if not anim in wanted:
			continue
		if not frames.has_animation(anim):
			frames.add_animation(anim)
			frames.set_animation_speed(anim, 24)
			frames.set_animation_loop(anim, false)
		var a := AtlasTexture.new()
		a.atlas = tex
		var w := xml.get_named_attribute_value_safe("width").to_float()
		var h := xml.get_named_attribute_value_safe("height").to_float()
		a.region = Rect2(xml.get_named_attribute_value_safe("x").to_float(), xml.get_named_attribute_value_safe("y").to_float(), w, h)
		if xml.has_attribute("frameX"):
			var fx := xml.get_named_attribute_value_safe("frameX").to_float()
			var fy := xml.get_named_attribute_value_safe("frameY").to_float()
			a.margin = Rect2(-fx, -fy, xml.get_named_attribute_value_safe("frameWidth").to_float() - w, xml.get_named_attribute_value_safe("frameHeight").to_float() - h)
		frames.add_frame(anim, a)
	if not frames.has_animation("BF idle dance"):
		return
	bf = AnimatedSprite2D.new()
	bf.sprite_frames = frames
	bf.centered = true
	bf_box.add_child(bf)
	bf.play("BF idle dance")
	bf.animation_finished.connect(func():
		if bf.animation == "BF idle dance":
			bf.frame = 0
			bf.play("BF idle dance"))
	_layout()


# --- Playing ------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or k.echo:
		return
	get_viewport().set_input_as_handled()
	if k.pressed and k.physical_keycode == KEY_ESCAPE:
		close()
		return
	if not ready_to_play:
		return
	if k.pressed and k.physical_keycode == KEY_SPACE:
		_pose("BF HEY!!")
		return
	var note := key_note(k.physical_keycode)
	if note < 0:
		return
	if k.pressed and not held.has(note):
		held[note] = true
		play_note(note)
	elif not k.pressed and held.has(note):
		held.erase(note)
		for t in trails:
			if t[0] == note and t[2] < 0.0:
				t[2] = t[1]


## The note a key plays, or -1.
static func key_note(code: int) -> int:
	var i := LOW_KEYS.find(code)
	if i >= 0:
		return FIRST_NOTE + i
	i = HIGH_KEYS.find(code)
	return FIRST_NOTE + 12 + i if i >= 0 else -1


func play_note(note: int) -> void:
	Achievements.unlock("chromatics")
	if sample:
		var p := voices[next_voice]
		next_voice = (next_voice + 1) % voices.size()
		var pitch := pow(2.0, (note - sample_note) / 12.0)
		p.stream = sample
		p.pitch_scale = pitch
		p.volume_db = 0.0
		p.play(sample_start)
		var stop_at := sample_length / pitch
		var tw := p.create_tween()
		tw.tween_interval(maxf(stop_at - 0.04, 0.0))
		tw.tween_property(p, "volume_db", -40.0, 0.04)
		tw.tween_callback(p.stop)
		p.set_meta("tween", tw)
	_pose(POSES[(note - FIRST_NOTE) % 4])
	trails.append([note, 0.0, -1.0])


func _pose(anim: String) -> void:
	if bf == null or not bf.sprite_frames.has_animation(anim):
		return
	bf.play(anim)
	bf.frame = 0
	pose_time = 0.6 if anim == "BF HEY!!" else 0.35


func _process(delta: float) -> void:
	if bf and pose_time > 0.0:
		pose_time -= delta
		if pose_time <= 0.0 and held.is_empty():
			bf.play("BF idle dance")
	for t in trails:
		t[1] += delta
	trails = trails.filter(func(t): return (t[1] - maxf(t[2], 0.0)) * ROLL_SPEED < size.y)
	roll.queue_redraw()
	keyboard.queue_redraw()


func close() -> void:
	set_process(false)
	for p in voices:
		p.stop()
	Music.set_game_running(Music.game_running)
	closed.emit()
	queue_free()


# --- Drawing ------------------------------------------------------------------------

func _layout() -> void:
	if keyboard == null:
		return
	var kh := 150.0
	keyboard.position = Vector2(40, size.y - kh - 30)
	keyboard.size = Vector2(size.x - 80, kh)
	help.position = Vector2(size.x - 30 - help.get_minimum_size().x, 30)
	bf_box.position = Vector2(size.x * 0.5, size.y - kh - 30 - 210)
	if bf:
		var target := clampf((size.y - kh - 140) / 440.0, 0.4, 1.2)
		bf.scale = Vector2(target, target)


func _white_count() -> int:
	return 15 # C3..C5


func _is_black(note: int) -> bool:
	return (note % 12) in [1, 3, 6, 8, 10]


## x and width of a key on the keyboard.
func _key_rect(note: int) -> Rect2:
	var ww := keyboard.size.x / _white_count()
	var whites := 0
	for n in range(FIRST_NOTE, note):
		if not _is_black(n):
			whites += 1
	if _is_black(note):
		return Rect2(whites * ww - ww * 0.3, 0, ww * 0.6, keyboard.size.y * 0.6)
	return Rect2(whites * ww, 0, ww, keyboard.size.y)


func _key_label(note: int) -> String:
	var i := note - FIRST_NOTE
	var code: int = LOW_KEYS[i] if i < 12 else HIGH_KEYS[i - 12]
	return OS.get_keycode_string(code)


func _note_color(note: int) -> Color:
	return ChartViewer.LANE_COLORS[(note - FIRST_NOTE) % 4]


func _draw_keyboard() -> void:
	var last := FIRST_NOTE + 24
	for pass_black in [false, true]:
		for note in range(FIRST_NOTE, last + 1):
			if _is_black(note) != pass_black:
				continue
			var r := _key_rect(note)
			var down := held.has(note)
			var fill: Color = (Color("1a1a1a") if pass_black else Color("f4f4f4"))
			if down:
				fill = _note_color(note)
			keyboard.draw_rect(r, fill)
			keyboard.draw_rect(r, Color.BLACK, false, 2.0)
			var label := _key_label(note)
			var col := Color.WHITE if pass_black else Color(0, 0, 0, 0.6)
			keyboard.draw_string(font, Vector2(r.position.x, r.end.y - 12), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, col)
			if note % 12 == 0:
				keyboard.draw_string(font, Vector2(r.position.x, r.end.y - 34), "C%d" % (note / 12 - 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, Color(0, 0, 0, 0.4))


## The piano roll: every note played rises from its key and scrolls away.
func _draw_roll() -> void:
	var base_y := keyboard.position.y
	var lines := Color(1, 1, 1, 0.04)
	for note in range(FIRST_NOTE, FIRST_NOTE + 25):
		if not _is_black(note):
			var r := _key_rect(note)
			roll.draw_line(Vector2(keyboard.position.x + r.position.x, 0), Vector2(keyboard.position.x + r.position.x, base_y), lines)
	for t in trails:
		var r := _key_rect(t[0])
		var top: float = base_y - t[1] * ROLL_SPEED
		var bottom: float = base_y - (t[1] - t[2]) * ROLL_SPEED if t[2] >= 0.0 else base_y
		var c := _note_color(t[0])
		var rect := Rect2(keyboard.position.x + r.position.x + 3, top, r.size.x - 6, maxf(bottom - top, 6.0))
		roll.draw_rect(rect, Color(c, 0.85))
		roll.draw_rect(rect, Color(1, 1, 1, 0.5), false, 1.5)
