class_name CustomTheme
extends RefCounted
## A custom theme: a folder in ~/.local/share/fnf-launcher/themes/ with a
## theme.txt and its files (images, fonts, sounds). theme.txt is plain
## "key: value" lines, made to be easy to write by hand:
##
##   name: Pink Week
##   based on: freeplay          (freeplay, steam or xbox 360)
##   background: bg.png          (an image, a .ogv video, or a colour)
##   accent: #ff4fa3
##   panel: #1a0b14 80%          (a colour, then how see-through: 80% = mostly solid)
##   move list: 5% -3% 110%      (shift right, shift down, size)
##   hide: clock, version
##
## Full reference: the "Custom Themes" wiki page (also written at the top of
## every theme.txt the editor saves).

const FILE := "theme.txt"
const BASES := {"freeplay": "freeplay", "steam": "steam", "xbox 360": "blades", "xbox": "blades", "blades": "blades"}
const BASE_NAMES := {"freeplay": "freeplay", "steam": "steam", "blades": "xbox 360"}
const COLOR_KEYS := ["accent", "text", "panel", "button", "button focus", "background color", "particles color", "achievement color"]
const FILE_KEYS := ["background", "background pattern", "logo", "font", "menu music", "sound scroll", "sound confirm", "sound cancel",
	"intro logo", "quips", "cursor", "achievement sound"]
const MONTHS := ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
## How the theme is picked each launch (Settings > THEME MODE).
const MODES := ["manual", "random", "daily", "seasonal"]
const MODE_NAMES := {"manual": "PICK MYSELF", "random": "RANDOM EACH LAUNCH", "daily": "THEME OF THE DAY", "seasonal": "SEASONAL"}
const FILE_TYPES := {
	"background": ["png", "jpg", "jpeg", "webp", "ogv"],
	"background pattern": ["png", "jpg", "jpeg", "webp"],
	"logo": ["png", "jpg", "jpeg", "webp"],
	"font": ["ttf", "otf"],
	"menu music": ["ogg", "mp3"],
	"sound scroll": ["ogg", "wav", "mp3"],
	"sound confirm": ["ogg", "wav", "mp3"],
	"sound cancel": ["ogg", "wav", "mp3"],
	"intro logo": ["png", "jpg", "jpeg", "webp"],
	"quips": ["txt"],
	"cursor": ["png"],
	"achievement sound": ["ogg", "wav", "mp3"],
}
const ALLOWED := ["txt", "png", "jpg", "jpeg", "webp", "ogv", "ttf", "otf", "ogg", "wav", "mp3"]
const HEADER := """# FNF Launcher theme. Edit it here or in the launcher (Settings > THEME > EDIT).
#   name: ...                    based on: freeplay | steam | xbox 360
#   accent / text / panel / button / button focus / background color:
#                                a colour (#ff4fa3, white, pink...), optional see-through % after it
#   background: file             an image or .ogv video in this folder
#   background pattern: file     an image tiled over the background, like wallpaper
#   pattern size: 80             how tall each tile is, in pixels
#   background dim: 40%          darken the background
#   mod art: on | off            show each mod's GameBanana art
#   logo: file                   an image shown on the menu (move it with "move logo")
#   font: file.ttf               the font for menus and popups
#   menu music: file.ogg         replaces the Freaky Menu theme
#   sound scroll / sound confirm / sound cancel: file
#   move <part>: 0% 0% 100%      shift right, shift down (in % of the screen), and size
#   hide: part, part             parts: see the editor's MOVE THINGS list
#   background gradient: #a #b   a top-to-bottom gradient instead of one colour
#   pattern opacity: 35%
#   particles: snow | bubbles | notes | stars | confetti | leaves | petals | bats | hearts | rain | embers | fireflies
#   particles color: #fff (or rainbow)    particles amount / speed / size: 100%
#   intro: skip                  go straight to the menu
#   intro credit: made by | orang entertainment       intro credit 2: ... | ...
#   intro title: friday | night | funkin              intro logo: file.png
#   quips: quips.txt             one "first line | second line" per line
#   arrow colors: #c24b99 #00ffff #12fa05 #f9393f     (left down up right)
#   visualizer colors: rainbow (or a list of colours)
#   viewer kaleidoscope / viewer shake / viewer ribbons: on | off    viewer effects: 100%
#   cursor: file.png             achievement sound: file.ogg
#   achievement position: top | bottom | top left | top right | bottom left | bottom right
#   achievement color: #1a1a1a 94%    ui scale: 100%    season: october, november
"""

## The theme on screen now (set by the menu; read by the intro, the chart
## viewer and the achievement popups).
static var current: CustomTheme
static var _session := ""
static var _session_set := false

var folder := ""
var values := {} # key -> raw text
var moves := {} # part id -> [dx%, dy%, scale%]
var hidden: Array[String] = []


## The theme to use this launch: the one picked, or one chosen by the theme
## mode (random / theme of the day / seasonal). Decided once per launch.
static func session_id(settings: Dictionary) -> String:
	if _session_set:
		return _session
	_session_set = true
	_session = settings.get("theme", "")
	var mode: String = settings.get("theme_mode", "manual")
	if mode == "manual":
		return _session
	var all := list()
	if all.is_empty():
		return _session
	match mode:
		"random":
			_session = all.pick_random().id()
		"daily":
			var d := Time.get_date_dict_from_system()
			_session = all[(d.year * 372 + d.month * 31 + d.day) % all.size()].id()
		"seasonal":
			var month: String = MONTHS[Time.get_date_dict_from_system().month - 1]
			var fits := all.filter(func(t): return month in str(t.values.get("season", "")).to_lower())
			if not fits.is_empty():
				_session = fits.pick_random().id()
	return _session


## Forget this launch's pick (after changing the theme or the mode).
static func reset_session(id := "") -> void:
	_session = id
	_session_set = id != ""


static func themes_dir() -> String:
	return Library.prefixes_dir().get_base_dir().path_join("themes")


## Every installed theme, sorted by name.
static func list() -> Array:
	var out := []
	var dir := themes_dir()
	if DirAccess.dir_exists_absolute(dir):
		for d in DirAccess.get_directories_at(dir):
			var t := load_from(dir.path_join(d))
			if t:
				out.append(t)
	out.sort_custom(func(a, b): return a.name().naturalnocasecmp_to(b.name()) < 0)
	return out


## The theme in `folder_name`, or null (none picked, or it's gone).
static func by_id(folder_name: String) -> CustomTheme:
	if folder_name == "":
		return null
	return load_from(themes_dir().path_join(folder_name))


static func load_from(path: String) -> CustomTheme:
	if not FileAccess.file_exists(path.path_join(FILE)):
		return null
	var t := CustomTheme.new()
	t.folder = path
	t.parse(FileAccess.get_file_as_string(path.path_join(FILE)))
	return t


## A new theme folder with sensible starting values. Returns it.
static func create(theme_name: String, base: String, accent: Color) -> CustomTheme:
	var t := CustomTheme.new()
	var slug := theme_name.to_lower().strip_edges()
	slug = RegEx.create_from_string("[^a-z0-9]+").sub(slug, "-", true).strip_edges().trim_prefix("-").trim_suffix("-")
	if slug == "":
		slug = "my-theme"
	var dir := themes_dir().path_join(slug)
	var n := 2
	while DirAccess.dir_exists_absolute(dir):
		dir = themes_dir().path_join("%s-%d" % [slug, n])
		n += 1
	DirAccess.make_dir_recursive_absolute(dir)
	t.folder = dir
	t.values = {"name": theme_name, "based on": BASE_NAMES.get(base, "freeplay"), "accent": "#" + accent.to_html(false), "mod art": "on"}
	t.save()
	return t


func id() -> String:
	return folder.get_file()


func name() -> String:
	return values.get("name", id())


## The skin underneath: "freeplay", "steam" or "blades".
func base() -> String:
	return BASES.get(str(values.get("based on", "freeplay")).to_lower().strip_edges(), "freeplay")


func color(key: String, fallback: Color) -> Color:
	return parse_color(values.get(key, ""), fallback)


## Absolute path of a file setting, or "" if unset or missing.
func file(key: String) -> String:
	var v: String = values.get(key, "")
	if v == "" or v.contains("..") or v.begins_with("/"):
		return ""
	var p := folder.path_join(v)
	return p if FileAccess.file_exists(p) else ""


func percent(key: String, fallback: float) -> float:
	var v: String = str(values.get(key, "")).replace("%", "").strip_edges()
	return v.to_float() if v.is_valid_float() else fallback


## "on"/"off"-style setting.
func flag(key: String, fallback: bool) -> bool:
	var v := str(values.get(key, "")).to_lower().strip_edges()
	if v == "":
		return fallback
	return not v in ["off", "no", "false", "0"]


## Several colours on one line: "#c24b99 #00ffff #12fa05 #f9393f"
func colors(key: String) -> Array:
	var out := []
	for part in str(values.get(key, "")).split(" ", false):
		var c := Color.from_string(part, Color(0, 0, 0, 0))
		if c.a > 0.0:
			out.append(c)
	return out


## "a | b" pairs from a quips file (or inline: "quip: a | b").
func quips() -> Array:
	var out := []
	var path := file("quips")
	var text := FileAccess.get_file_as_string(path) if path != "" else ""
	for line in text.split("\n"):
		var bits := line.split("|")
		if bits.size() >= 2 and bits[0].strip_edges() != "":
			out.append([bits[0].strip_edges().to_lower(), bits[1].strip_edges().to_lower()])
	return out


## Two lines split by "|" ("made by | orang entertainment"), or [].
func pair(key: String) -> Array:
	var bits := str(values.get(key, "")).split("|")
	return [bits[0].strip_edges().to_lower(), bits[1].strip_edges().to_lower()] if bits.size() >= 2 else []


func mod_art() -> bool:
	return str(values.get("mod art", "on")).to_lower() not in ["off", "no", "false", "0"]


## "#ff4fa3", "#ff4fa3 80%", "pink", "white 50%" -> Color
static func parse_color(text: String, fallback: Color) -> Color:
	var parts := text.strip_edges().split(" ", false)
	if parts.is_empty():
		return fallback
	var c := Color.from_string(parts[0], fallback)
	if parts.size() > 1 and parts[1].ends_with("%") and parts[1].trim_suffix("%").is_valid_float():
		c.a = clampf(parts[1].trim_suffix("%").to_float() / 100.0, 0.0, 1.0)
	return c


static func color_text(c: Color) -> String:
	var t := "#" + c.to_html(false)
	if c.a < 0.995:
		t += " %d%%" % roundi(c.a * 100.0)
	return t


func parse(text: String) -> void:
	values.clear()
	moves.clear()
	hidden.clear()
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var colon := line.find(":")
		if colon < 0:
			continue
		var key := line.left(colon).strip_edges().to_lower()
		var value := line.substr(colon + 1).strip_edges()
		if key.begins_with("move "):
			var nums := []
			for p in value.split(" ", false):
				var n := p.replace("%", "")
				if n.is_valid_float():
					nums.append(n.to_float())
			while nums.size() < 3:
				nums.append(100.0 if nums.size() == 2 else 0.0)
			moves[key.substr(5).strip_edges()] = nums.slice(0, 3)
		elif key == "hide":
			for p in value.split(",", false):
				if p.strip_edges() != "":
					hidden.append(p.strip_edges().to_lower())
		else:
			values[key] = value


func save() -> void:
	var lines := PackedStringArray([HEADER])
	var order := ["name", "author", "based on"] + COLOR_KEYS + ["background", "background pattern", "pattern size", "background dim", "mod art", "logo", "font", "menu music", "sound scroll", "sound confirm", "sound cancel"]
	for key in order:
		if values.get(key, "") != "":
			lines.append("%s: %s" % [key, values[key]])
	for key in values:
		if not key in order and values[key] != "":
			lines.append("%s: %s" % [key, values[key]])
	for part in moves:
		var m: Array = moves[part]
		if m != [0.0, 0.0, 100.0]:
			lines.append("move %s: %s%% %s%% %s%%" % [part, _num(m[0]), _num(m[1]), _num(m[2])])
	if not hidden.is_empty():
		lines.append("hide: " + ", ".join(hidden))
	DirAccess.make_dir_recursive_absolute(folder)
	var f := FileAccess.open(folder.path_join(FILE), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")


static func _num(v: float) -> String:
	return str(snappedf(v, 0.1)).trim_suffix(".0")


## Copies a file into the theme folder and returns its name there.
func add_file(path: String) -> String:
	var name_in := path.get_file()
	var dest := folder.path_join(name_in)
	if path != dest:
		var n := 2
		while FileAccess.file_exists(dest):
			dest = folder.path_join("%s-%d.%s" % [name_in.get_basename(), n, name_in.get_extension()])
			n += 1
		DirAccess.copy_absolute(path, dest)
	return dest.get_file()


## Applies fonts and colours to a skin's Theme resource.
func style(t: Theme) -> void:
	var font_path := file("font")
	if font_path != "":
		var f := FontFile.new()
		if f.load_dynamic_font(font_path) == OK:
			t.default_font = f
	if values.get("text", "") != "":
		var text := color("text", Color.WHITE)
		t.set_color("font_color", "Label", text)
		for kind in ["Button", "OptionButton", "LineEdit", "CheckBox", "CheckButton"]:
			t.set_color("font_color", kind, text)
	if values.get("panel", "") != "":
		for type in ["PanelContainer", "NowPlayingPanel"]:
			var box := t.get_stylebox("panel", type)
			if box is StyleBoxFlat:
				box = box.duplicate()
				box.bg_color = color("panel", box.bg_color)
				t.set_stylebox("panel", type, box)
	for pair in [["button", ["normal"]], ["button focus", ["focus", "hover", "pressed"]]]:
		if values.get(pair[0], "") == "":
			continue
		var bg := color(pair[0], Color.BLACK)
		# Text on buttons: black or white, whichever reads better on the theme's colour.
		var readable := Color.BLACK if bg.get_luminance() > 0.6 else Color.WHITE
		for kind in ["Button", "OptionButton", "LineEdit"]:
			for state in pair[1]:
				var box := t.get_stylebox(state, kind)
				if box is StyleBoxFlat:
					box = box.duplicate()
					box.bg_color = color(pair[0], box.bg_color)
					t.set_stylebox(state, kind, box)
			if pair[0] == "button focus":
				for c in ["font_focus_color", "font_hover_color", "font_pressed_color"]:
					t.set_color(c, kind, readable)
			elif values.get("text", "") == "":
				t.set_color("font_color", kind, readable)


func sound(kind: String) -> AudioStream:
	var p := file("sound " + kind)
	return _audio(p) if p != "" else null


static func _audio(path: String) -> AudioStream:
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
	return null


# --- Sharing (.fnftheme = a zip of the folder) ---------------------------------------

func export_to(path: String) -> bool:
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		return false
	for f in DirAccess.get_files_at(folder):
		if f.get_extension().to_lower() in ALLOWED:
			zip.start_file(f)
			zip.write_file(FileAccess.get_file_as_bytes(folder.path_join(f)))
			zip.close_file()
	zip.close()
	return true


## Installs a .fnftheme. Returns the theme, or null if it isn't a valid one.
static func import_from(path: String) -> CustomTheme:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return null
	var files := zip.get_files()
	if not FILE in files:
		zip.close()
		return null
	var probe := CustomTheme.new()
	probe.parse(zip.read_file(FILE).get_string_from_utf8())
	var t := create(probe.name(), probe.base(), Color.WHITE)
	for f in files:
		# Only plain files at the top level with expected types: nothing can escape the folder.
		if f.contains("/") or f.contains("\\") or f.contains("..") or not f.get_extension().to_lower() in ALLOWED:
			continue
		var out := FileAccess.open(t.folder.path_join(f), FileAccess.WRITE)
		if out:
			out.store_buffer(zip.read_file(f))
	zip.close()
	return load_from(t.folder)
