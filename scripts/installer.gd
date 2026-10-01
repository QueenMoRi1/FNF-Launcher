extends Control
## Graphical installer. FNF-Launcher-Installer.sh starts this once Godot, the app
## files and the FNF assets are in place; it then runs the remaining steps
## through the same script ("--run-steps") and shows its "@tag" progress lines.

const ASSETS := "res://assets/funkin/"
const STEPS := [
	["app", "Launcher files"],
	["assets", "FNF menu assets"],
	["godot", "Game engine (Godot)"],
	["proton", "GE-Proton"],
	["runtime", "Steam Linux Runtime 4.0"],
	["shortcuts", "Games folder & app menu"],
	["steam", "Steam shortcut & artwork"],
]
const STATE_ICONS := {
	"pending": ["..", Color(0.55, 0.55, 0.6)],
	"active": [">>", UiKit.YELLOW],
	"ok": ["OK", Color("7cff7c")],
	"warn": ["!!", Color("ffb347")],
	"fail": ["XX", Color("ff5a5a")],
}
const LOGO_FRAME := Rect2(0, 0, 894, 670)
const GF_FRAME := Rect2(0, 0, 717, 648)

var script_path := ""
var probe := {}
var rows := {} # step id -> {icon, detail, bar, state}
var options := {} # "proton" / "runtime" / "steam" -> CheckBox
var current := ""
var failed := false
var finished := false

var _pipe: FileAccess
var _stderr: FileAccess
var _pid := -1
var _buffer := ""
var gf: TextureRect
var title: Label
var buttons: HBoxContainer
var options_box: VBoxContainer
var sfx := {}


func _ready() -> void:
	InputSetup.apply()
	theme = UiKit.make_theme()
	var args := OS.get_cmdline_user_args()
	var i := args.find("--installer")
	if i >= 0 and i + 1 < args.size():
		script_path = args[i + 1]
	if script_path == "":
		# Some Godot builds (e.g. AppImages) drop arguments after "--".
		script_path = OS.get_environment("FNF_INSTALLER_SCRIPT")
	for s in ["scrollMenu", "confirmMenu", "cancelMenu"]:
		var p := AudioStreamPlayer.new()
		p.stream = load(ASSETS + s + ".ogg")
		add_child(p)
		sfx[s] = p
	Music.play_menu_theme()
	_build()
	_probe()
	if "--auto-install" in args:
		_install.call_deferred()


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = load(ASSETS + "menuDesat.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color("9271fd")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	gf = TextureRect.new()
	gf.texture = _frame("gfDanceTitle.png", GF_FRAME)
	gf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gf.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(gf)
	gf.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	gf.offset_left = 10
	gf.offset_right = 520
	gf.offset_top = -470
	gf.offset_bottom = 10
	gf.pivot_offset = Vector2(255, 480)

	var logo := TextureRect.new()
	logo.texture = _frame("logoBumpin.png", LOGO_FRAME)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(20, 6)
	logo.size = Vector2(500, 300)
	add_child(logo)
	var word := Alphabet.make_text("Launcher", 44)
	word.alignment = BoxContainer.ALIGNMENT_CENTER
	word.position = Vector2(20, 268)
	word.size = Vector2(500, 50)
	add_child(word)

	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	panel.offset_left = -720
	panel.offset_right = -30
	panel.offset_top = 30
	panel.offset_bottom = -30
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	title = UiKit.add_label(box, "INSTALL FNF LAUNCHER", 32, UiKit.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for step in STEPS:
		box.add_child(_step_row(step[0], step[1]))

	options_box = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 6)
	options_box.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(options_box)

	buttons = UiKit.add_row(box)


func _step_row(id: String, label: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var icon := UiKit.add_label(row, "", 22)
	icon.autowrap_mode = TextServer.AUTOWRAP_OFF
	icon.custom_minimum_size = Vector2(44, 0)
	var step_name := UiKit.add_label(row, label.to_upper(), 22)
	step_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	var detail := UiKit.add_label(col, "", 15, Color(0.75, 0.75, 0.8))
	detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.custom_minimum_size = Vector2(0, 0)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = 100
	bar.show_percentage = false
	bar.visible = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiKit.YELLOW
	bar.add_theme_stylebox_override("fill", fill)
	col.add_child(bar)
	rows[id] = {"icon": icon, "detail": detail, "bar": bar, "state": ""}
	_set_state(id, "pending", "")
	return col


func _set_state(id: String, state: String, detail: String) -> void:
	var row: Dictionary = rows.get(id, {})
	if row.is_empty():
		return
	row.state = state
	row.icon.text = STATE_ICONS[state][0]
	row.icon.add_theme_color_override("font_color", STATE_ICONS[state][1])
	if detail != "":
		row.detail.text = detail
	if state != "active":
		row.bar.visible = false


## Asks the script what's already installed, then shows the options.
func _probe() -> void:
	for id in ["app", "assets", "godot"]:
		_set_state(id, "ok", "Ready.")
	if script_path == "" or not FileAccess.file_exists(script_path):
		title.text = "START THE INSTALLER FILE INSTEAD"
		_set_state("proton", "fail", "This screen is opened by FNF-Launcher-Installer.sh.")
		UiKit.add_button(buttons, "CLOSE", get_tree().quit).grab_focus.call_deferred()
		return
	var out := []
	OS.execute("bash", [script_path, "--probe"], out)
	var parsed = JSON.parse_string(out[0] if not out.is_empty() else "")
	probe = parsed if parsed is Dictionary else {}
	var steam: bool = probe.get("steam", "") != ""

	if probe.get("ge_proton", "") != "":
		_set_state("proton", "ok", "Already installed (%s)." % probe.ge_proton)
	elif steam:
		_option("proton", "Install GE-Proton (needed to play the Windows FNF games)")
	else:
		_set_state("proton", "warn", "Needs Steam. Install Steam, then run this again.")

	if int(probe.get("runtime", 0)) == 1:
		_set_state("runtime", "ok", "Already installed.")
	elif steam:
		_option("runtime", "Install Steam Linux Runtime 4.0 through Steam (needed to play)")
	else:
		_set_state("runtime", "warn", "Needs Steam.")

	_set_state("shortcuts", "pending", "Games go in " + probe.get("games", "~/Games/FNF"))

	if not steam:
		_set_state("steam", "warn", "Steam isn't installed.")
	else:
		var text := "Add to Steam with custom covers & artwork"
		if probe.get("shortcut", "") != "":
			text = "Refresh the Steam artwork (already in your library)"
		elif int(probe.get("steam_running", 0)) == 0:
			text += " (start Steam first!)"
		_option("steam", text)

	UiKit.add_label(options_box, "Installs to " + probe.get("app", "~/.local/share/fnf-launcher/app").get_base_dir(), 15, Color(0.7, 0.7, 0.75))
	var install := UiKit.add_button(buttons, "  INSTALL  ", _install)
	UiKit.add_button(buttons, "CANCEL", get_tree().quit)
	install.grab_focus.call_deferred()


func _option(id: String, text: String) -> void:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = true
	check.add_theme_font_size_override("font_size", 18)
	options_box.add_child(check)
	options[id] = check


func _install() -> void:
	if _pid > 0:
		return
	sfx.confirmMenu.play()
	var args := [script_path, "--run-steps"]
	for id in ["proton", "runtime", "steam"]:
		if options.has(id) and not options[id].button_pressed:
			args.append("--no-" + id)
	for child in options_box.get_children():
		child.queue_free()
	for child in buttons.get_children():
		child.queue_free()
	title.text = "INSTALLING..."
	var info := OS.execute_with_pipe("bash", args, false)
	if info.is_empty():
		_finish(false, "Couldn't start the install script.")
		return
	_pipe = info.stdio
	_stderr = info.stderr
	_pid = info.pid


func _process(_delta: float) -> void:
	# GF bops to Freaky Menu (102 BPM).
	var beat := fmod(Music.position() * 102.0 / 60.0, 1.0)
	gf.scale = Vector2.ONE * (1.0 + 0.03 * (1.0 - beat))
	if _pipe == null:
		return
	var chunk := _pipe.get_buffer(65536)
	if not chunk.is_empty():
		_buffer += chunk.get_string_from_utf8()
		while "\n" in _buffer:
			var cut := _buffer.find("\n")
			_handle(_buffer.left(cut))
			_buffer = _buffer.substr(cut + 1)
	if not OS.is_process_running(_pid):
		_pipe = null
		_pid = -1
		if not finished:
			_finish(false, "The install stopped unexpectedly.")


func _handle(line: String) -> void:
	if not line.begins_with("@"):
		return
	var tag := line.get_slice(" ", 0)
	var rest := line.substr(tag.length() + 1)
	match tag:
		"@step":
			_end_current()
			current = rest.get_slice(" ", 0)
			_set_state(current, "active", rest.substr(current.length() + 1))
			sfx.scrollMenu.play()
		"@progress":
			if rows.has(current):
				rows[current].bar.visible = true
				rows[current].bar.value = rest.to_int()
		"@ok":
			if rows.has(current):
				rows[current].detail.text = rest
		"@warn":
			_set_state(current, "warn", rest)
		"@fail":
			_set_state(current, "fail", rest)
			failed = true
		"@done":
			_end_current()
			_finish(not failed, "")


func _end_current() -> void:
	if rows.has(current) and rows[current].state == "active":
		_set_state(current, "ok", "")


func _finish(success: bool, message: String) -> void:
	finished = true
	if message != "" and rows.has(current):
		_set_state(current, "fail", message)
	for child in buttons.get_children():
		child.queue_free()
	if success:
		title.text = "ALL DONE! LET'S FUNK"
		sfx.confirmMenu.play()
		UiKit.add_label(options_box, "Put FNF games in %s, or press F4 in the launcher to download them." % probe.get("games", "~/Games/FNF"), 17)
		UiKit.add_button(buttons, "  PLAY NOW  ", _play_now).grab_focus.call_deferred()
		UiKit.add_button(buttons, "CLOSE", get_tree().quit)
	else:
		title.text = "SOMETHING WENT WRONG"
		sfx.cancelMenu.play()
		UiKit.add_label(options_box, "Check your internet connection and run the installer again. Your games and settings are safe.", 17)
		UiKit.add_button(buttons, "CLOSE", get_tree().quit).grab_focus.call_deferred()


func _play_now() -> void:
	OS.create_process(OS.get_environment("HOME").path_join(".local/bin/fnf-launcher"), [])
	get_tree().quit()


func _frame(file: String, region: Rect2) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = load(ASSETS + file)
	tex.region = region
	return tex
