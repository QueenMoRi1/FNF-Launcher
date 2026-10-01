extends Control
## Launcher controller: library, input, overlays and launching. The game list
## itself is drawn by the active skin (scripts/skins/).

const SKINS := ["freeplay", "steam"]
const SKIN_NAMES := {"freeplay": "FREEPLAY", "steam": "STEAM"}
const KEY_HINTS := "ENTER PLAY  F2 EDIT  F3 FRIENDS  F4 DOWNLOAD  F5 RESCAN  ESC SETTINGS"
const PAD_HINTS := "A PLAY  Y EDIT  START FRIENDS  R3 DOWNLOAD  X RESCAN  B SETTINGS"
## Menu idle time before the XP "Where'd you go?????" popup.
const IDLE_SECONDS := 3600.0

var library := Library.new()
var gb := GameBanana.new()
var friends := FriendsService.new()
var downloader := Downloader.new()
var proton_dir := ""
var keys: Array = []
var icons := {} # folder -> {"texture": Texture2D, "color": Color}
var arts := {} # folder -> Texture2D (GameBanana art)
var selected := 0
var view: SkinView

var overlay: UiKit.Overlay
var file_dialog: FileDialog
var input_cooldown := 0.0
var hold_dir := 0
var hold_time := 0.0
var launching := false
var game_pid := -1
var idle_time := 0.0
var _was_blocked := false
## Widgets of the open downloads / friends overlay (freed with the overlay).
var dl_ui := {}
var downloads_label: Label
var friends_list: VBoxContainer
var friends_header: Label
var _gb_busy := false
var _gb_again := false

var now_playing: NowPlaying
var proton_label: Label
var message_label: Label
var hints_label: Label
var sfx := {}
var run_timer: Timer
var message_timer: Timer


func _ready() -> void:
	InputSetup.apply()
	add_child(gb)
	add_child(friends)
	add_child(downloader)
	downloader.gamebanana = gb
	downloader.changed.connect(_on_downloads_changed)
	downloader.installed.connect(_on_game_installed)
	downloader.job_failed.connect(_on_download_failed)
	friends.updated.connect(_on_friends_updated)
	_build_chrome()
	library.scan()
	_sort_keys()
	_apply_skin()
	Music.start_playlist(library.all_songs())
	if Music.intro_flash:
		Music.intro_flash = false
		_flash()
	downloader.games_dir = library.games_dir
	Discord.configure(library.settings.discord_enabled, library.settings.discord_client_id)
	friends.configure(library.settings.friends_server, library.settings.friends_share)
	Music.track_changed.connect(_update_presence)
	_update_presence()
	_show_proton_popup()
	_load_gamebanana()


## Everything that stays the same across skins: hint bar, messages, timers, sfx.
func _build_chrome() -> void:
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.6)
	add_child(bar)
	bar.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bar.offset_top = -44
	hints_label = UiKit.add_label(bar, "", 16)
	hints_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hints_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hints_label.offset_left = 16
	hints_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_update_hints()
	Input.joy_connection_changed.connect(func(_device, _connected): _update_hints())

	proton_label = UiKit.add_label(bar, "", 18)
	proton_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	proton_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	proton_label.offset_right = -16
	proton_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	proton_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	message_label = UiKit.add_label(self, "", 22)
	message_label.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	message_label.offset_top = -120
	message_label.offset_bottom = -80

	# Download queue status, visible anywhere in the menu while jobs run.
	downloads_label = UiKit.add_label(self, "", 16)
	downloads_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	downloads_label.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	downloads_label.offset_left = 16
	downloads_label.offset_top = -74
	downloads_label.offset_bottom = -50
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0, 0, 0, 0.7)
	chip.set_content_margin_all(4)
	chip.content_margin_left = 10
	chip.content_margin_right = 10
	chip.set_corner_radius_all(4)
	downloads_label.add_theme_stylebox_override("normal", chip)
	downloads_label.hide()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	message_timer = Timer.new()
	message_timer.one_shot = true
	message_timer.timeout.connect(_on_message_timeout)
	add_child(message_timer)

	run_timer = Timer.new()
	run_timer.wait_time = 1.0
	run_timer.timeout.connect(_check_game)
	add_child(run_timer)

	for s in ["scroll", "confirm", "cancel"]:
		var player := AudioStreamPlayer.new()
		add_child(player)
		sfx[s] = player


func _update_hints() -> void:
	var text := PAD_HINTS if Input.get_connected_joypads().size() > 0 else KEY_HINTS
	if friends.is_configured() and not friends.online.is_empty():
		text += "   ·   %d FRIEND%s ONLINE" % [friends.online.size(), "" if friends.online.size() == 1 else "S"]
	hints_label.text = text


func _flash() -> void:
	var white := ColorRect.new()
	white.color = Color.WHITE
	white.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(white)
	white.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var tw := create_tween()
	tw.tween_property(white, "modulate:a", 0.0, 1.0)
	tw.tween_callback(white.queue_free)


func _play(sound: String) -> void:
	if sfx[sound].stream:
		sfx[sound].play()


# --- Skins / list ------------------------------------------------------------

## (Re)builds the active skin's view. Also used after edits and rescans.
func _apply_skin(keep_path := "") -> void:
	if keep_path == "" and not keys.is_empty() and selected < keys.size():
		keep_path = keys[selected]
	_sort_keys()
	selected = clampi(keys.find(keep_path), 0, maxi(keys.size() - 1, 0))
	if view:
		view.queue_free()
	match library.settings.skin:
		"steam":
			view = SteamView.new()
		_:
			view = FreeplayView.new()
	add_child(view)
	move_child(view, 0)
	view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	UiKit.accent = view.accent
	theme = view.make_theme()
	message_label.add_theme_color_override("font_color", UiKit.accent)
	var streams := view.sounds()
	for s in sfx:
		sfx[s].stream = streams.get(s)

	if now_playing:
		now_playing.queue_free()
	now_playing = NowPlaying.new()
	add_child(now_playing)
	move_child(now_playing, view.get_index() + 1)
	if view.widget_at_bottom:
		now_playing.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
		now_playing.grow_vertical = GROW_DIRECTION_BEGIN
		now_playing.offset_top = -60
		now_playing.offset_bottom = -60
	else:
		now_playing.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
		now_playing.offset_top = 16
	now_playing.offset_left = -436
	now_playing.offset_right = -16

	var hint := "Drop FNF game folders into\n%s\nthen press F5 to rescan." % library.games_dir
	view.build(_items(), selected, hint)


func _sort_keys() -> void:
	keys = library.games.keys()
	keys.sort_custom(func(a, b): return library.games[a].name.naturalnocasecmp_to(library.games[b].name) < 0)


func _items() -> Array:
	var out := []
	for path in keys:
		var entry: Dictionary = library.games[path]
		var icon := _icon_for(path, entry)
		out.append({"path": path, "entry": entry, "icon": icon.texture, "color": icon.color, "art": arts.get(path)})
	return out


func _icon_for(path: String, entry: Dictionary) -> Dictionary:
	if not icons.has(path):
		var img := IconLoader.load_icon(path, entry)
		icons[path] = {
			"texture": ImageTexture.create_from_image(img),
			"color": IconLoader.tint_color(img),
		}
	return icons[path]


func _change_selection(delta: int) -> void:
	if keys.is_empty():
		return
	selected = wrapi(selected + delta, 0, keys.size())
	_play("scroll")
	view.set_selected(selected)


# --- GameBanana --------------------------------------------------------------

## Matches unmatched games on GameBanana, then loads art for every game.
func _load_gamebanana() -> void:
	if _gb_busy:
		_gb_again = true
		return
	_gb_busy = true
	for path in keys.duplicate():
		if not library.games.has(path):
			continue
		var entry: Dictionary = library.games[path]
		if not entry.has("gb"):
			var found: Dictionary = await gb.auto_match(entry.name)
			found.erase("thumb_url")
			entry.gb = found if not found.is_empty() else {"none": true}
			library.save()
		await _load_art(path)
	_gb_busy = false
	if _gb_again:
		_gb_again = false
		_load_gamebanana()


func _load_art(path: String) -> void:
	var entry: Dictionary = library.games.get(path, {})
	var url: String = entry.get("gb", {}).get("art_url", "")
	var tex: Texture2D = null
	if url != "":
		tex = await gb.fetch_image(url)
	if tex:
		arts[path] = tex
	else:
		arts.erase(path)
	var i := keys.find(path)
	if i >= 0 and is_instance_valid(view):
		view.set_art(i, tex)


# --- Loop / input ------------------------------------------------------------

## True while a game is running or the launcher isn't the focused window:
## controllers are global, so otherwise the launcher would react to in-game input.
func _input_blocked() -> bool:
	return game_pid > 0 or not get_window().has_focus()


func _input(event: InputEvent) -> void:
	if _input_blocked():
		get_viewport().set_input_as_handled() # keeps the GUI (overlay buttons) out of it too
		return
	var stick := event as InputEventJoypadMotion
	if stick:
		if absf(stick.axis_value) > 0.5:
			idle_time = 0.0
	elif event is InputEventMouseMotion or event.is_pressed():
		idle_time = 0.0


func _process(delta: float) -> void:
	if Cheats.active:
		return
	if not overlay and game_pid < 0 and not launching and not is_instance_valid(file_dialog):
		idle_time += delta
		if idle_time >= IDLE_SECONDS:
			idle_time = 0.0
			_open_overlay(XpPopup.build(self, _close_overlay))
	if is_instance_valid(file_dialog):
		return
	if _input_blocked():
		_was_blocked = true
		return
	if _was_blocked:
		# Ignore the button press that just closed the game / refocused us.
		_was_blocked = false
		input_cooldown = 0.5
		hold_dir = 0
	if input_cooldown > 0.0:
		input_cooldown -= delta
		return
	if overlay:
		if Input.is_action_just_pressed("ui_cancel"):
			_play("cancel")
			_close_overlay()
		return
	if launching:
		return

	var dir: int
	if view.nav_axis == SkinView.Axis.HORIZONTAL:
		dir = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	else:
		dir = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	if dir != hold_dir:
		hold_dir = dir
		hold_time = 0.0
		if dir != 0:
			_change_selection(dir)
	elif dir != 0:
		hold_time += delta
		if hold_time > 0.4:
			hold_time -= 0.08
			_change_selection(dir)

	if Input.is_action_just_pressed("music_pause"):
		Music.toggle_pause()
	elif Input.is_action_just_pressed("music_prev"):
		Music.prev()
	elif Input.is_action_just_pressed("music_next"):
		Music.next()

	if Input.is_action_just_pressed("ui_accept"):
		_launch_selected()
	elif Input.is_action_just_pressed("edit"):
		_open_edit()
	elif Input.is_action_just_pressed("rescan"):
		_rescan()
	elif Input.is_action_just_pressed("friends"):
		_open_friends()
	elif Input.is_action_just_pressed("download"):
		_open_downloader()
	elif Input.is_action_just_pressed("ui_cancel"):
		_open_settings()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if overlay or launching or mb == null or not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_change_selection(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			_change_selection(1)


func _show_message(text: String, seconds := 4.0) -> void:
	message_label.text = text
	message_timer.start(seconds)


func _on_message_timeout() -> void:
	if game_pid < 0:
		message_label.text = ""


# --- Overlays ----------------------------------------------------------------

func _open_overlay(o: UiKit.Overlay) -> void:
	if overlay and overlay != o:
		overlay.queue_free()
	overlay = o
	input_cooldown = 0.15
	if o.focus_target:
		o.focus_target.grab_focus.call_deferred()


func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	friends.fast = false
	_on_downloads_changed.call_deferred()
	get_viewport().gui_release_focus()
	input_cooldown = 0.2


func _show_proton_popup() -> void:
	proton_dir = Proton.find_ge_proton()
	proton_label.text = "GE-PROTON: " + (Proton.version_name(proton_dir) if proton_dir != "" else "NOT FOUND")
	proton_label.add_theme_color_override("font_color", Color("7cff7c") if proton_dir != "" else UiKit.PINK)
	_open_overlay(ProtonPopup.build(self, proton_dir, _show_proton_popup, _close_overlay))


## `pending` carries unsaved edits while the GameBanana picker is open.
func _open_edit(pending := {}) -> void:
	if keys.is_empty():
		return
	var path: String = keys[selected]
	var entry: Dictionary = library.games[path]
	if pending.is_empty():
		pending = {"name": entry.name, "exe": entry.exe, "icon": entry.icon_override, "gb": entry.get("gb", {})}
	var o := UiKit.make_overlay(self, "EDIT GAME", 900)
	UiKit.add_label(o.box, path, 16, Color(0.7, 0.7, 0.7))

	UiKit.add_label(o.box, "NAME", 20, UiKit.accent)
	var name_edit := LineEdit.new()
	name_edit.text = pending.name
	name_edit.select_all_on_focus = true
	name_edit.text_changed.connect(func(text: String): pending.name = text)
	o.box.add_child(name_edit)

	UiKit.add_label(o.box, "EXECUTABLE", 20, UiKit.accent)
	var exe_pick := OptionButton.new()
	var exes := Library.find_exes(path, true)
	for exe in exes:
		exe_pick.add_item(exe.trim_prefix(path + "/"))
	exe_pick.select(maxi(exes.find(pending.exe), 0))
	exe_pick.item_selected.connect(func(i: int): pending.exe = exes[i])
	o.box.add_child(exe_pick)

	UiKit.add_label(o.box, "ICON", 20, UiKit.accent)
	var icon_row := UiKit.add_row(o.box)
	icon_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var preview := TextureRect.new()
	var preview_entry := entry.duplicate()
	preview_entry.icon_override = pending.icon
	preview.texture = ImageTexture.create_from_image(IconLoader.load_icon(path, preview_entry))
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(64, 64)
	icon_row.add_child(preview)
	var set_icon := func(file: String) -> void:
		pending.icon = file
		preview_entry.icon_override = file
		preview.texture = ImageTexture.create_from_image(IconLoader.load_icon(path, preview_entry))
	var image_filter := PackedStringArray(["*.png, *.ico, *.jpg, *.jpeg, *.webp ; Images"])
	UiKit.add_button(icon_row, "CHOOSE ICON...", func(): _pick_file(false, image_filter, path, set_icon))
	UiKit.add_button(icon_row, "AUTO", set_icon.bind(""))

	UiKit.add_label(o.box, "GAMEBANANA PAGE", 20, UiKit.accent)
	var gb_label := UiKit.add_label(o.box, _gb_text(pending.gb), 18)
	var gb_row := UiKit.add_row(o.box)
	gb_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	UiKit.add_button(gb_row, "FIND ON GAMEBANANA...", _open_gb_picker.bind(pending))
	var link := LineEdit.new()
	link.placeholder_text = "or paste a gamebanana.com/mods/... link"
	link.size_flags_horizontal = SIZE_EXPAND_FILL
	gb_row.add_child(link)
	UiKit.add_button(gb_row, "USE LINK", func(): _use_gb_link(link.text, pending, gb_label))
	var clear_gb := func() -> void:
		pending.gb = {"none": true}
		gb_label.text = _gb_text(pending.gb)
	UiKit.add_button(gb_row, "CLEAR", clear_gb)

	var save := func() -> void:
		var new_name: String = pending.name.strip_edges()
		entry.name = new_name if new_name != "" else path.get_file()
		if pending.exe != "":
			entry.exe = pending.exe
		entry.icon_override = pending.icon
		var gb_changed: bool = entry.get("gb", {}) != pending.gb
		entry.gb = pending.gb
		library.save()
		icons.erase(path)
		_play("confirm")
		_close_overlay()
		_apply_skin(path)
		if gb_changed:
			_load_art(path)
	name_edit.text_submitted.connect(func(_text: String): save.call())

	var buttons := UiKit.add_row(o.box)
	UiKit.add_button(buttons, "SAVE", save)
	UiKit.add_button(buttons, "CANCEL", _close_overlay)
	o.focus_target = name_edit
	_open_overlay(o)


func _gb_text(info: Dictionary) -> String:
	if info.get("name", "") != "":
		return "%s\n%s" % [info.name, info.url]
	return "Not matched yet. Use FIND or paste the mod's link."


func _open_gb_picker(pending: Dictionary) -> void:
	var o := UiKit.make_overlay(self, "FIND ON GAMEBANANA", 900)
	var row := UiKit.add_row(o.box)
	var query := LineEdit.new()
	query.text = " ".join(GameBanana.normalize(pending.name))
	query.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(query)
	var status := UiKit.add_label(o.box, "", 18)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	o.box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list)
	var run := func(): _gb_search(query.text, list, status, pending)
	UiKit.add_button(row, "SEARCH", run)
	query.text_submitted.connect(func(_text: String): run.call())
	var bottom := UiKit.add_row(o.box)
	o.focus_target = UiKit.add_button(bottom, "BACK", _open_edit.bind(pending))
	_open_overlay(o)
	run.call()


func _gb_search(query: String, list: VBoxContainer, status: Label, pending: Dictionary) -> void:
	for child in list.get_children():
		child.queue_free()
	status.text = "SEARCHING..."
	var results: Array = await gb.search(query)
	if not is_instance_valid(list):
		return
	status.text = "PICK THE RIGHT MOD:" if not results.is_empty() else "NOTHING FOUND (OR YOU'RE OFFLINE)"
	for r in results.slice(0, 10):
		var b := UiKit.add_button(list, r.name, _pick_gb.bind(r, pending))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.expand_icon = true
		b.custom_minimum_size = Vector2(0, 72)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_load_thumb(b, r.thumb_url)
	if list.get_child_count() > 0:
		(list.get_child(0) as Button).grab_focus.call_deferred()


func _load_thumb(button: Button, url: String) -> void:
	var tex: Texture2D = await gb.fetch_image(url)
	if tex and is_instance_valid(button):
		button.icon = tex


func _pick_gb(result: Dictionary, pending: Dictionary) -> void:
	pending.gb = result.duplicate()
	pending.gb.erase("thumb_url")
	_open_edit(pending)


func _use_gb_link(text: String, pending: Dictionary, label: Label) -> void:
	var id := GameBanana.id_from_url(text)
	if id < 0:
		label.text = "That's not a gamebanana.com/mods/... link."
		return
	label.text = "Looking it up..."
	var result: Dictionary = await gb.get_mod(id)
	if not is_instance_valid(label):
		return
	if result.is_empty():
		label.text = "Couldn't load that mod (offline?)."
		return
	result.erase("thumb_url")
	pending.gb = result
	label.text = _gb_text(result)


func _open_settings() -> void:
	var o := UiKit.make_overlay(self, "SETTINGS", 900)
	UiKit.add_label(o.box, "GAMES FOLDER", 20, UiKit.accent)
	UiKit.add_label(o.box, library.games_dir, 18)
	var row := UiKit.add_row(o.box)
	o.focus_target = UiKit.add_button(row, "CHANGE FOLDER...", func(): _pick_file(true, PackedStringArray(), library.games_dir, _set_games_dir))
	UiKit.add_button(row, "OPEN FOLDER", func(): OS.shell_open(library.games_dir))
	UiKit.add_button(row, "RESCAN", _set_games_dir.bind(library.games_dir))
	UiKit.add_button(row, "DOWNLOAD A GAME", _open_downloader)

	UiKit.add_label(o.box, "SKIN", 20, UiKit.accent)
	row = UiKit.add_row(o.box)
	UiKit.add_button(row, " < ", _cycle_skin.bind(-1))
	var skin_label := UiKit.add_label(row, SKIN_NAMES[library.settings.skin], 22)
	skin_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	skin_label.custom_minimum_size = Vector2(220, 0)
	skin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.add_button(row, " > ", _cycle_skin.bind(1))

	UiKit.add_label(o.box, "DISCORD RICH PRESENCE", 20, UiKit.accent)
	row = UiKit.add_row(o.box)
	var toggle := Button.new()
	row.add_child(toggle)
	toggle.toggle_mode = true
	toggle.button_pressed = library.settings.discord_enabled
	toggle.text = "ON" if toggle.button_pressed else "OFF"
	toggle.toggled.connect(func(on: bool): toggle.text = "ON" if on else "OFF")
	var app_id := LineEdit.new()
	app_id.placeholder_text = "Discord Application ID"
	app_id.text = library.settings.discord_client_id
	app_id.custom_minimum_size = Vector2(360, 0)
	row.add_child(app_id)
	UiKit.add_button(row, "SAVE", func(): _save_discord(toggle.button_pressed, app_id.text))

	UiKit.add_label(o.box, "FRIENDS SERVER", 20, UiKit.accent)
	row = UiKit.add_row(o.box)
	var server := LineEdit.new()
	server.placeholder_text = "https://your-worker.workers.dev"
	server.text = library.settings.friends_server
	server.custom_minimum_size = Vector2(420, 0)
	row.add_child(server)
	var share := Button.new()
	row.add_child(share)
	share.toggle_mode = true
	share.button_pressed = library.settings.friends_share
	share.text = "SHARE MY STATUS" if share.button_pressed else "DON'T SHARE"
	share.toggled.connect(func(on: bool): share.text = "SHARE MY STATUS" if on else "DON'T SHARE")
	UiKit.add_button(row, "SAVE", func(): _save_friends(server.text, share.button_pressed))

	row = UiKit.add_row(o.box)
	UiKit.add_button(row, "GE-PROTON INFO", _show_proton_popup)
	UiKit.add_button(row, "OPEN LOGS", _open_logs)
	UiKit.add_button(row, "CLOSE", _close_overlay)
	UiKit.add_button(row, "QUIT", get_tree().quit)
	_open_overlay(o)


func _cycle_skin(step: int) -> void:
	var i := SKINS.find(library.settings.skin)
	library.settings.skin = SKINS[wrapi(i + step, 0, SKINS.size())]
	library.save()
	_close_overlay()
	_apply_skin()
	_open_settings()


func _save_discord(on: bool, id: String) -> void:
	id = id.strip_edges()
	if on and not id.is_valid_int():
		_show_message("PASTE YOUR DISCORD APPLICATION ID FIRST")
		return
	library.settings.discord_enabled = on
	library.settings.discord_client_id = id
	library.save()
	Discord.configure(on, id)
	_update_presence()
	_show_message("DISCORD PRESENCE " + ("ON" if on else "OFF"))


func _save_friends(server: String, share: bool) -> void:
	server = server.strip_edges()
	if server != "" and not server.begins_with("https://") and not server.begins_with("http://"):
		_show_message("THE FRIENDS SERVER MUST BE A FULL https:// LINK")
		return
	library.settings.friends_server = server
	library.settings.friends_share = share
	library.save()
	friends.configure(server, share)
	_update_presence()
	_show_message("FRIENDS SETTINGS SAVED")


func _set_games_dir(dir: String) -> void:
	library.games_dir = dir
	downloader.games_dir = dir
	_close_overlay()
	_rescan()


func _open_logs() -> void:
	var logs := ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(logs)
	OS.shell_open(logs)


## save_name: when set, asks where to save a new file with this default name.
func _pick_file(dir_mode: bool, filters: PackedStringArray, start_dir: String, on_pick: Callable, save_name := "") -> void:
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR if dir_mode else FileDialog.FILE_MODE_OPEN_FILE
	if save_name != "":
		file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		file_dialog.current_file = save_name
	file_dialog.filters = filters
	file_dialog.current_dir = start_dir
	# Steam's Game Mode (gamescope) has no system file dialog: a native one would
	# never appear and leave the launcher waiting. Godot's own works with a pad.
	file_dialog.use_native_dialog = not _in_game_mode() and DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
	file_dialog.size = Vector2i(960, 600)
	add_child(file_dialog)
	var done := func(picked: String) -> void:
		file_dialog.queue_free()
		input_cooldown = 0.2
		on_pick.call(picked)
	if dir_mode:
		file_dialog.dir_selected.connect(done)
	else:
		file_dialog.file_selected.connect(done)
	file_dialog.canceled.connect(_on_dialog_canceled)
	file_dialog.popup_centered()


static func _in_game_mode() -> bool:
	return OS.get_environment("XDG_CURRENT_DESKTOP").to_lower() == "gamescope" \
		or OS.has_environment("GAMESCOPE_WAYLAND_DISPLAY")


func _on_dialog_canceled() -> void:
	file_dialog.queue_free()
	input_cooldown = 0.2


# --- Actions -----------------------------------------------------------------

## `installed`/`gb`: a game the downloader just added, with its known GameBanana
## mod. The current selection is kept so an install doesn't interrupt browsing.
func _rescan(installed := "", gb_info := {}, source := "") -> void:
	library.scan()
	if installed != "" and library.games.has(installed):
		if not gb_info.is_empty():
			library.games[installed].gb = gb_info
		if source != "":
			library.games[installed].source = source
		library.save()
	icons.clear()
	_apply_skin()
	var songs := library.all_songs()
	Music.update_songs(songs)
	if installed == "":
		_play("scroll")
		_show_message("FOUND %d GAME%s, %d SONG%s" % [keys.size(), "" if keys.size() == 1 else "S", songs.size(), "" if songs.size() == 1 else "S"])
	_load_gamebanana()


func _launch_selected() -> void:
	if keys.is_empty():
		return
	proton_dir = Proton.find_ge_proton()
	if not Proton.can_launch(proton_dir):
		_play("cancel")
		_show_proton_popup()
		return
	var path: String = keys[selected]
	var entry: Dictionary = library.games[path]
	if not FileAccess.file_exists(entry.exe):
		_play("cancel")
		_show_message("EXE NOT FOUND - PRESS F2 TO PICK ONE")
		return
	launching = true
	_play("confirm")
	view.play_launch(selected, _start_game.bind(entry))


func _start_game(entry: Dictionary) -> void:
	launching = false
	var log_path := ProjectSettings.globalize_path("user://logs/%s.log" % entry.slug)
	var pid := Proton.launch(entry.exe, entry.prefix, proton_dir, log_path)
	if pid <= 0:
		_show_message("FAILED TO START THE GAME")
		return
	game_pid = pid
	Music.set_game_running(true)
	message_label.text = "NOW PLAYING: %s" % entry.name.to_upper()
	run_timer.start()
	_set_playing_presence(entry)


func _check_game() -> void:
	if game_pid > 0 and OS.is_process_running(game_pid):
		return
	game_pid = -1
	run_timer.stop()
	Music.set_game_running(false)
	# Ask to come back to the front so the controller works again right away.
	get_window().move_to_foreground()
	get_window().grab_focus()
	message_label.text = ""
	_update_presence()


# --- Discord -----------------------------------------------------------------

func _update_presence() -> void:
	if game_pid > 0:
		return
	friends.set_status("", {})
	Discord.set_activity({
		"type": 0,
		"details": "Choosing a mod",
		"state": "♪ " + Music.current().title,
		"assets": {"large_image": "logo", "large_text": "FNF Launcher"},
	})


func _set_playing_presence(entry: Dictionary) -> void:
	var activity := {
		"type": 0,
		"details": "Playing " + entry.name,
		"state": "via " + Proton.version_name(proton_dir),
		"timestamps": {"start": int(Time.get_unix_time_from_system())},
		"assets": {"large_image": "logo", "large_text": entry.name},
	}
	var info: Dictionary = entry.get("gb", {})
	if info.get("url", "") != "":
		if info.get("art_url", "") != "":
			activity.assets = {"large_image": info.art_url, "large_text": info.name}
		activity.buttons = [{"label": "Download on GameBanana", "url": info.url}]
	Discord.set_activity(activity)
	friends.set_status(entry.name, info if info.get("url", "") != "" else {})


# --- Downloads ---------------------------------------------------------------

## Downloads overlay: add links to the queue and watch progress. Closing it
## doesn't stop anything.
func _open_downloader(url := "") -> void:
	var o := UiKit.make_overlay(self, "DOWNLOADS", 960)
	UiKit.add_label(o.box, "Paste a GameBanana mod page or a direct .zip / .7z / .rar link. Downloads keep going after you close this.", 17)
	var row := UiKit.add_row(o.box)
	var link := LineEdit.new()
	link.placeholder_text = "https://gamebanana.com/mods/..."
	link.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(link)
	var add := func() -> void:
		if link.text.strip_edges() != "":
			downloader.add_url(link.text)
			link.text = ""
	link.text_submitted.connect(func(_text: String): add.call())
	UiKit.add_button(row, "ADD TO QUEUE", add)
	var archives := PackedStringArray(["*.zip, *.7z, *.rar ; Archives"])
	UiKit.add_button(row, "FROM FILE...", func(): _pick_file(false, archives, OS.get_environment("HOME").path_join("Downloads"), downloader.add_file))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	o.box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	var bottom := UiKit.add_row(o.box)
	var lists := PackedStringArray(["*.txt ; Collection lists"])
	var home := OS.get_environment("HOME")
	UiKit.add_button(bottom, "IMPORT LIST...", func(): _pick_file(false, lists, home, _import_collection))
	UiKit.add_button(bottom, "EXPORT LIST...", func(): _pick_file(false, lists, home, _export_collection, "fnf-collection.txt"))
	UiKit.add_button(bottom, "CLEAR FINISHED", downloader.clear_finished)
	var close := UiKit.add_button(bottom, "CLOSE", _close_overlay)
	dl_ui = {"overlay": o, "list": list, "rows": {}, "shape": ""}
	o.focus_target = link if url == "" else close
	_open_overlay(o)
	downloads_label.hide()
	if url != "":
		downloader.add_url(url)
	_refresh_downloads()


func _dl_open() -> bool:
	return not dl_ui.is_empty() and is_instance_valid(dl_ui.overlay) and overlay == dl_ui.overlay


func _on_downloads_changed() -> void:
	var text := downloader.summary()
	downloads_label.text = text
	downloads_label.visible = text != "" and not _dl_open()
	if _dl_open():
		_refresh_downloads()


## Rebuilds rows only when jobs or their states change (keeps controller focus);
## otherwise just updates text and progress.
func _refresh_downloads() -> void:
	var shape := ",".join(downloader.jobs.map(func(j): return "%d:%s" % [j.id, j.state]))
	if shape != dl_ui.shape:
		dl_ui.shape = shape
		var list: VBoxContainer = dl_ui.list
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
		dl_ui.rows = {}
		for job in downloader.jobs:
			list.add_child(_download_row(job))
		if downloader.jobs.is_empty():
			UiKit.add_label(list, "Nothing queued yet.", 20, Color(0.7, 0.7, 0.7))
	for job in downloader.jobs:
		var ui: Dictionary = dl_ui.rows.get(job.id, {})
		if ui.is_empty():
			continue
		ui.status.text = _job_status(job)
		ui.bar.value = maxf(job.progress, 0.0)
		ui.bar.visible = job.state in ["downloading", "unpacking"]


func _download_row(job: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	box.add_child(top)
	var name_label := UiKit.add_label(top, job.name, 20)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	if job.state in ["looking_up", "choose", "queued", "downloading", "unpacking"]:
		UiKit.add_button(top, "CANCEL", downloader.cancel.bind(job.id))
	var color := Color("7cff7c") if job.state == "done" else (UiKit.PINK if job.state == "failed" else Color(0.75, 0.75, 0.75))
	var status := UiKit.add_label(box, "", 16, color)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = 1.0
	bar.show_percentage = false
	box.add_child(bar)
	if job.state == "choose":
		for f in job.files:
			var b := UiKit.add_button(box, "%s   (%s)" % [f.file, String.humanize_size(f.size)], downloader.choose.bind(job.id, f))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	dl_ui.rows[job.id] = {"status": status, "bar": bar}
	return box


func _job_status(job: Dictionary) -> String:
	match job.state:
		"looking_up":
			return "Looking it up on GameBanana..."
		"choose":
			return "This mod has several downloads. Pick one:"
		"queued":
			return "Waiting in queue"
		"downloading":
			var pct := "%d%%   " % int(job.progress * 100) if job.progress >= 0.0 else ""
			return "Downloading   " + pct + job.message
		"unpacking":
			return "Unpacking..."
		"done":
			return "Done ✓   " + job.message
	return job.message


func _on_game_installed(game_path: String, gb_info: Dictionary, source: String) -> void:
	_play("confirm")
	_rescan(game_path, gb_info, source)
	_show_message("INSTALLED " + game_path.get_file().to_upper(), 6.0)


func _export_collection(path: String) -> void:
	if path.get_extension() == "":
		path += ".txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_show_message("COULDN'T SAVE " + path.get_file().to_upper())
		return
	f.store_string(library.export_collection())
	f = null
	var linked := library.games.values().filter(func(e): return Library.download_link(e) != "").size()
	_play("confirm")
	_show_message("SAVED %d OF %d GAMES TO %s" % [linked, library.games.size(), path.get_file().to_upper()], 6.0)


## Queues every link in a collection list, skipping games already installed.
func _import_collection(path: String) -> void:
	var urls := Library.parse_collection(FileAccess.get_file_as_string(path))
	var have := {}
	for entry in library.games.values():
		var id := int(entry.get("gb", {}).get("id", -1))
		if id >= 0:
			have[id] = true
		if entry.get("source", "") != "":
			have[entry.source] = true
	var queued := 0
	var skipped := 0
	for url in urls:
		var id := GameBanana.id_from_url(url)
		if have.has(id) or have.has(url):
			skipped += 1
			continue
		downloader.add_url(url)
		queued += 1
	if urls.is_empty():
		_show_message("NO DOWNLOAD LINKS IN " + path.get_file().to_upper())
	else:
		_show_message("QUEUED %d GAME%s, SKIPPED %d YOU ALREADY HAVE" % [queued, "" if queued == 1 else "S", skipped], 6.0)


func _on_download_failed(job_name: String, message: String) -> void:
	_play("cancel")
	if not _dl_open():
		_show_message(("%s: %s" % [job_name, message]).to_upper(), 8.0)


# --- Friends -----------------------------------------------------------------

func _open_friends() -> void:
	var o := UiKit.make_overlay(self, "FRIENDS", 900)
	friends_header = UiKit.add_label(o.box, "", 18)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	o.box.add_child(scroll)
	friends_list = VBoxContainer.new()
	friends_list.size_flags_horizontal = SIZE_EXPAND_FILL
	friends_list.add_theme_constant_override("separation", 10)
	scroll.add_child(friends_list)
	var bottom := UiKit.add_row(o.box)
	o.focus_target = UiKit.add_button(bottom, "CLOSE", _close_overlay)
	_open_overlay(o)
	friends.fast = true
	_fill_friends()
	friends.poll()


func _on_friends_updated() -> void:
	_update_hints()
	if is_instance_valid(friends_list):
		_fill_friends()


func _fill_friends() -> void:
	for child in friends_list.get_children():
		friends_list.remove_child(child)
		child.queue_free()
	if not friends.is_configured():
		friends_header.text = "Set up the friends server in Settings first (ESC > FRIENDS SERVER)."
		return
	if friends.friends.is_empty():
		friends_header.text = "Couldn't read your Steam friends list. Is Steam installed and logged in?"
		return
	var shown := 0
	for f in friends.friends:
		var status: Dictionary = friends.online.get(f.id, {})
		if status.is_empty():
			continue
		shown += 1
		friends_list.add_child(_friend_row(f, status))
	friends_header.text = "%d of %d Steam friends are on FNF Launcher right now" % [shown, friends.friends.size()]
	if shown == 0:
		UiKit.add_label(friends_list, "No friends online right now.", 22)


func _friend_row(f: Dictionary, status: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(64, 64)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(avatar)
	_load_avatar(avatar, f.avatar_url)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(info)
	UiKit.add_label(info, f.name, 22)
	var playing: String = status.get("playing", "")
	var minutes := int((Time.get_unix_time_from_system() * 1000.0 - float(status.get("ts", 0))) / 60000.0)
	var line := ("Playing " + playing) if playing != "" else "In the menu"
	if minutes >= 2:
		line += "   ·   %d min ago" % minutes
	UiKit.add_label(info, line, 18, UiKit.accent if playing != "" else Color(0.7, 0.7, 0.7))
	var mod_url: String = status.get("mod_url", "")
	if playing != "" and GameBanana.id_from_url(mod_url) >= 0:
		if _have_mod(GameBanana.id_from_url(mod_url)):
			var have := UiKit.add_label(row, "INSTALLED", 18, Color("7cff7c"))
			have.autowrap_mode = TextServer.AUTOWRAP_OFF
			have.size_flags_vertical = SIZE_SHRINK_CENTER
		else:
			var get_it := UiKit.add_button(row, "GET IT", _open_downloader.bind(mod_url))
			get_it.size_flags_vertical = SIZE_SHRINK_CENTER
	return row


func _have_mod(id: int) -> bool:
	for path in library.games:
		if int(library.games[path].get("gb", {}).get("id", -1)) == id:
			return true
	return false


func _load_avatar(rect: TextureRect, url: String) -> void:
	var tex: Texture2D = await gb.fetch_image(url)
	if tex and is_instance_valid(rect):
		rect.texture = tex
