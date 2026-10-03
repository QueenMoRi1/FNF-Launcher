class_name ToolsUI
extends RefCounted
## The per-mod tools in the edit dialog (updates, Proton & performance, save
## backups, health check) and the matching Settings rows (keybinds, mod
## updates, health check for every mod, Funkin' Wrapped, theme gallery).

const FPS_CHOICES := [0, 30, 60, 90, 120, 144]


## Unix time -> the player's local time (Godot's conversions are UTC).
static func _local(unix: int) -> int:
	return unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60


static func _date(unix: int) -> String:
	if unix <= 0:
		return "?"
	var d := Time.get_datetime_dict_from_unix_time(_local(unix))
	return "%d-%02d-%02d" % [d.year, d.month, d.day]


static func _heading(box: Control, text: String) -> void:
	UiKit.add_label(box, text, 20, UiKit.accent)


static func _note(box: Control, text: String) -> Label:
	return UiKit.add_label(box, text, 16, Color(1, 1, 1, 0.7))


# --- Edit dialog -------------------------------------------------------------------

static func edit_sections(main: Node, box: VBoxContainer, path: String, entry: Dictionary, pending: Dictionary) -> void:
	_updates_section(main, box, path, entry)
	if OS.get_name() != "Windows":
		_performance_section(box, pending)
	_backups_section(main, box, entry)
	_health_section(main, box, path, entry)


static func _update_text(entry: Dictionary) -> String:
	if entry.has("update_available"):
		return "UPDATE AVAILABLE: uploaded %s" % _date(int(entry.update_available))
	if entry.has("gb_seen"):
		return "Up to date (newest upload %s)" % _date(int(entry.gb_seen))
	return "Not checked yet."


static func _updates_section(main: Node, box: VBoxContainer, path: String, entry: Dictionary) -> void:
	if int(entry.get("gb", {}).get("id", 0)) <= 0:
		return
	_heading(box, "UPDATES")
	var status := UiKit.add_label(box, _update_text(entry), 18)
	var row := UiKit.add_row(box)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var update_btn := UiKit.add_button(row, "UPDATE NOW", main._update_mod.bind(path))
	update_btn.visible = entry.has("update_available")
	UiKit.add_button(row, "CHECK NOW", func():
		status.text = "Checking GameBanana..."
		await main.mod_updates.check_one(entry)
		main.library.save()
		status.text = _update_text(entry)
		update_btn.visible = entry.has("update_available"))
	_note(box, "Updating swaps in the newest download. Your saves stay (they live in the prefix), and the old version is kept in the .old folder of your games folder.")


static func _performance_section(box: VBoxContainer, pending: Dictionary) -> void:
	var opts: Dictionary = pending.options
	_heading(box, "PROTON & PERFORMANCE")
	var protons := Proton.list_all()
	var pick := OptionButton.new()
	pick.add_item("NEWEST GE-PROTON (default)")
	var current: String = opts.get("proton", "")
	for i in protons.size():
		pick.add_item(protons[i].name)
		if protons[i].path == current:
			pick.select(i + 1)
	pick.item_selected.connect(func(i: int):
		if i == 0:
			opts.erase("proton")
		else:
			opts.proton = protons[i - 1].path)
	box.add_child(pick)
	var has_gamescope := Proton.find_gamescope() != ""
	var row := UiKit.add_row(box)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var gs := CheckBox.new()
	gs.text = "RUN IN GAMESCOPE"
	gs.button_pressed = opts.get("gamescope", false)
	gs.disabled = not has_gamescope
	gs.toggled.connect(func(on: bool): opts.gamescope = on)
	row.add_child(gs)
	var full := CheckBox.new()
	full.text = "FULLSCREEN"
	full.button_pressed = opts.get("fullscreen", false)
	full.disabled = not has_gamescope
	full.toggled.connect(func(on: bool): opts.fullscreen = on)
	row.add_child(full)
	var fps := OptionButton.new()
	for f in FPS_CHOICES:
		fps.add_item("FPS LIMIT: OFF" if f == 0 else "FPS LIMIT: %d" % f)
	fps.select(maxi(FPS_CHOICES.find(int(opts.get("fps", 0))), 0))
	fps.disabled = not has_gamescope
	fps.item_selected.connect(func(i: int): opts.fps = FPS_CHOICES[i])
	row.add_child(fps)
	_note(box, "Gamescope gives any mod fullscreen and an FPS limit. In Steam's Game Mode you're already in gamescope, so these do nothing there (use Steam's own FPS limit)." if has_gamescope
		else "Install gamescope to get fullscreen and an FPS limit for any mod.")
	var env := LineEdit.new()
	env.text = opts.get("env", "")
	env.placeholder_text = "environment variables, e.g. PROTON_USE_WINED3D=1"
	env.text_changed.connect(func(t: String):
		if t.strip_edges() == "":
			opts.erase("env")
		else:
			opts.env = t.strip_edges())
	box.add_child(env)


static func _backups_section(main: Node, box: VBoxContainer, entry: Dictionary) -> void:
	_heading(box, "SAVE BACKUPS")
	_note(box, "Your saves are backed up every time you start the mod (the last %d are kept)." % ModSaves.KEEP)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	var fill := func(refill: Callable) -> void:
		for c in list.get_children():
			c.queue_free()
		var backups := ModSaves.backups(entry)
		if backups.is_empty():
			_note(list, "No backups yet. Play the mod once." if ModSaves.sol_files(entry).is_empty() else "No backups yet.")
		for b in backups:
			var r := UiKit.add_row(list)
			r.alignment = BoxContainer.ALIGNMENT_BEGIN
			var when := Time.get_datetime_string_from_unix_time(_local(int(b.time))).replace("T", "  ")
			var l := UiKit.add_label(r, "%s   %d file%s%s" % [when, b.files.size(), "" if b.files.size() == 1 else "s", ("   (" + str(b.reason) + ")") if str(b.get("reason", "")) != "" else ""], 16)
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var restore := UiKit.add_button(r, "RESTORE", func(): pass)
			restore.pressed.connect(func():
				if restore.text == "RESTORE":
					restore.text = "SURE? PRESS AGAIN"
					return
				var n := ModSaves.restore(entry, b.id)
				Achievements.unlock("restore")
				main._show_message("RESTORED %d SAVE FILE%s" % [n, "" if n == 1 else "S"])
				refill.call(refill))
	var row := UiKit.add_row(box)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	UiKit.add_button(row, "BACK UP NOW", func():
		var id := ModSaves.backup(entry, "by hand")
		main._show_message("SAVES BACKED UP" if id != "" else "NOTHING NEW TO BACK UP")
		fill.call(fill))
	UiKit.add_button(row, "OPEN BACKUPS FOLDER", func():
		DirAccess.make_dir_recursive_absolute(ModSaves.backups_dir(entry))
		OS.shell_open(ModSaves.backups_dir(entry)))
	box.add_child(list)
	fill.call(fill)


static func _health_section(main: Node, box: VBoxContainer, path: String, entry: Dictionary) -> void:
	_heading(box, "HEALTH CHECK")
	var results := VBoxContainer.new()
	results.add_theme_constant_override("separation", 6)
	var run := func(again: Callable) -> void:
		for c in results.get_children():
			c.queue_free()
		Achievements.unlock("health")
		for p in ModHealth.check(path, entry, "" if OS.get_name() == "Windows" else main._proton_for(entry)):
			_problem_row(main, results, path, entry, p, again)
	UiKit.add_button(UiKit.add_row(box), "CHECK THIS MOD", func(): run.call(run)).get_parent().alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(results)


static func _problem_row(main: Node, parent: Control, path: String, entry: Dictionary, p: Dictionary, again: Callable) -> void:
	var r := UiKit.add_row(parent)
	r.alignment = BoxContainer.ALIGNMENT_BEGIN
	var mark: String = {"ok": "✓", "warn": "!", "error": "✗"}[p.level]
	var color: Color = {"ok": Color("7CFC9A"), "warn": Color("ffd23f"), "error": Color("ff6b6b")}[p.level]
	var l := UiKit.add_label(r, "%s  %s" % [mark, p.text], 16, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match p.fix:
		"pick_exe":
			UiKit.add_button(r, "PICK THE EXE AGAIN", func():
				var exes := Library.find_exes(path)
				if exes.is_empty():
					main._show_message("NO .EXE IN THAT FOLDER")
					return
				entry.exe = Library.pick_exe(exes, path.get_file())
				main.library.save()
				main._show_message("NOW USING " + entry.exe.get_file().to_upper())
				again.call(again))
		"case_files":
			UiKit.add_button(r, "FIX NAMES", func():
				var n := ModHealth.fix_case(entry.exe.get_base_dir())
				main._show_message("ADDED %d CORRECTLY-NAMED COP%s" % [n, "Y" if n == 1 else "IES"])
				again.call(again))


# --- Settings ----------------------------------------------------------------------

static func settings_sections(main: Node, box: VBoxContainer) -> void:
	_keybinds_section(main, box)
	_heading(box, "MOD TOOLS")
	var row := UiKit.add_row(box)
	UiKit.add_button(row, "CHECK MODS FOR UPDATES", func():
		main._show_message("CHECKING GAMEBANANA FOR UPDATES...")
		main.mod_updates.check_all(main.library))
	UiKit.add_button(row, "HEALTH CHECK ALL MODS", open_health_all.bind(main))
	var auto := CheckButton.new()
	auto.text = "CHECK FOR MOD UPDATES BY ITSELF (twice a day)"
	auto.button_pressed = main.library.settings.get("mod_updates_auto", true)
	auto.toggled.connect(func(on: bool):
		main.library.settings.mod_updates_auto = on
		main.library.save())
	box.add_child(auto)
	_heading(box, "FUN STUFF")
	row = UiKit.add_row(box)
	UiKit.add_button(row, "FUNKIN' WRAPPED", func():
		main._close_overlay()
		Wrapped.open(main))
	UiKit.add_button(row, "THEME GALLERY", func(): ThemeGallery.open(main))


static func _keybinds_section(main: Node, box: VBoxContainer) -> void:
	_heading(box, "KEYBINDS")
	var settings: Dictionary = main.library.settings
	var on := CheckButton.new()
	on.text = "SAME NOTE KEYS IN EVERY MOD"
	on.button_pressed = Keybinds.enabled(settings)
	box.add_child(on)
	var row := UiKit.add_row(box)
	var keys := Keybinds.keys_from(settings)
	var store := func() -> void:
		settings.keybinds = {"on": on.button_pressed, "keys": keys}
		main.library.save()
		if on.button_pressed:
			Achievements.unlock("keybinds")
	on.toggled.connect(func(_on: bool): store.call())
	for i in 4:
		var b := UiKit.add_button(row, Keybinds.shown(keys[i]), func(): pass)
		b.custom_minimum_size = Vector2(80, 0)
		b.pressed.connect(func():
			b.text = "PRESS A KEY"
			var catcher := KeyCatcher.new()
			main.add_child(catcher)
			var code: int = await catcher.caught
			var flx := Keybinds.name_for(code)
			if flx == "":
				if code != KEY_ESCAPE:
					main._show_message("FNF MODS CAN'T USE THAT KEY. TRY A LETTER, NUMBER OR ARROW")
			else:
				keys[i] = flx
				store.call()
			b.text = Keybinds.shown(keys[i]))
	_note(box, "Left, down, up, right. They're written into each mod's saved controls when you start it (Psych and Kade Engine mods). A mod needs to have run once before.")


## Every mod's health check in one list.
static func open_health_all(main: Node) -> void:
	var o := UiKit.make_overlay(main, "HEALTH CHECK", 1000)
	var list: VBoxContainer = main._scroll_list(o.box)
	var bad := 0
	for path in main.library.games:
		var entry: Dictionary = main.library.games[path]
		var problems := ModHealth.check(path, entry, "" if OS.get_name() == "Windows" else main._proton_for(entry))
		var worst := "ok"
		for p in problems:
			if p.level == "error" or (p.level == "warn" and worst == "ok"):
				worst = p.level
		UiKit.add_label(list, entry.name, 20, {"ok": Color("7CFC9A"), "warn": Color("ffd23f"), "error": Color("ff6b6b")}[worst])
		if worst != "ok":
			bad += 1
		for p in problems:
			if p.level != "ok" or worst == "ok":
				_problem_row(main, list, path, entry, p, func(_x): pass)
	Achievements.unlock("health")
	UiKit.add_label(o.box, "%d of %d mods need a look." % [bad, main.library.games.size()] if bad > 0 else "Everything looks healthy.", 18)
	o.focus_target = UiKit.add_button(UiKit.add_row(o.box), "CLOSE", main._close_overlay)
	main._open_overlay(o)


## Waits for one key press (for setting a keybind).
class KeyCatcher extends Node:
	signal caught(keycode: int)

	func _input(event: InputEvent) -> void:
		var k := event as InputEventKey
		if k == null or not k.pressed or k.echo:
			return
		get_viewport().set_input_as_handled()
		caught.emit(k.physical_keycode if k.physical_keycode != 0 else k.keycode)
		queue_free()
