class_name ThemeGallery
extends RefCounted
## Settings > FUN STUFF > THEME GALLERY: custom themes shared on the friends
## server (see server/worker.js). Browse and install other people's themes, or
## share yours. Uploads return a token so you can take your theme down again;
## it's kept in settings.shared_themes ({id: token}).

const MAX_BYTES := 1500000


static func server(main: Node) -> String:
	return str(main.library.settings.get("friends_server", "")).strip_edges().trim_suffix("/")


static func open(main: Node) -> void:
	if server(main) == "":
		main._show_message("THE GALLERY LIVES ON A FRIENDS SERVER: SET ONE UP IN SETTINGS FIRST", 6.0)
		return
	var o := UiKit.make_overlay(main, "THEME GALLERY", 1000)
	var status := UiKit.add_label(o.box, "Loading...", 18)
	var list: VBoxContainer = main._scroll_list(o.box)
	var row := UiKit.add_row(o.box)
	o.focus_target = UiKit.add_button(row, "SHARE MY THEME", share.bind(main, status))
	UiKit.add_button(row, "CLOSE", main._close_overlay)
	main._open_overlay(o)
	var themes = await _request(main, "/themes", HTTPClient.METHOD_GET)
	if not is_instance_valid(list):
		return
	if not themes is Array:
		status.text = "Couldn't reach the friends server."
		return
	status.text = "%d theme%s shared" % [themes.size(), "" if themes.size() == 1 else "s"] if not themes.is_empty() else "Nothing shared yet. Be the first!"
	var mine: Dictionary = main.library.settings.get("shared_themes", {})
	for t in themes:
		var r := UiKit.add_row(list)
		r.alignment = BoxContainer.ALIGNMENT_BEGIN
		var l := UiKit.add_label(r, "%s   by %s   ·   %s" % [t.get("name", "?"), t.get("author", "?") if str(t.get("author", "")) != "" else "someone", String.humanize_size(int(t.get("size", 0)))], 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id := str(t.get("id", ""))
		UiKit.add_button(r, "INSTALL", install.bind(main, id))
		if mine.has(id):
			var del := UiKit.add_button(r, "TAKE DOWN", func(): pass)
			del.pressed.connect(func():
				var res = await _request(main, "/themes/%s?token=%s" % [id, str(mine[id]).uri_encode()], HTTPClient.METHOD_DELETE)
				if res is Dictionary and res.get("ok", false):
					mine.erase(id)
					main.library.save()
					r.queue_free()
				else:
					main._show_message("COULDN'T TAKE IT DOWN"))


static func install(main: Node, id: String) -> void:
	var t = await _request(main, "/themes/" + id, HTTPClient.METHOD_GET)
	if not t is Dictionary or not t.has("data"):
		main._show_message("COULDN'T DOWNLOAD THAT THEME")
		return
	var bytes := Marshalls.base64_to_raw(str(t.data))
	var tmp := OS.get_cache_dir().path_join("fnf-gallery-%s.fnftheme" % id)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		main._show_message("COULDN'T SAVE THE THEME")
		return
	f.store_buffer(bytes)
	f.close()
	main._import_theme(tmp) # validates and unpacks it safely
	DirAccess.remove_absolute(tmp)
	Achievements.unlock("gallery")


static func share(main: Node, status: Label) -> void:
	var th: CustomTheme = main.active_theme
	if th == null:
		main._show_message("PICK A THEME TO SHARE FIRST")
		return
	var tmp := OS.get_cache_dir().path_join("fnf-share-%s.fnftheme" % th.id())
	if not th.export_to(tmp):
		main._show_message("COULDN'T PACK THE THEME")
		return
	var bytes := FileAccess.get_file_as_bytes(tmp)
	DirAccess.remove_absolute(tmp)
	if bytes.size() > MAX_BYTES:
		main._show_message("THAT THEME IS OVER 1.5 MB (BIG VIDEO OR MUSIC?). SHARE IT AS A FILE INSTEAD", 6.0)
		return
	status.text = "Uploading %s..." % th.name()
	var author := str(th.values.get("author", ""))
	var res = await _request(main, "/themes", HTTPClient.METHOD_POST,
		{"name": th.name(), "author": author, "data": Marshalls.raw_to_base64(bytes)})
	if res is Dictionary and res.has("id"):
		var mine: Dictionary = main.library.settings.get("shared_themes", {})
		mine[res.id] = res.token
		main.library.settings.shared_themes = mine
		main.library.save()
		main._close_overlay()
		main._show_message("SHARED! EVERYONE ON YOUR FRIENDS SERVER CAN INSTALL IT", 6.0)
		open(main)
	else:
		status.text = "Upload failed: %s" % (res.get("error", "no answer") if res is Dictionary else "couldn't reach the server")


static func _request(main: Node, path: String, method: int, body = null) -> Variant:
	var http := HTTPRequest.new()
	http.timeout = 30
	main.add_child(http)
	var headers := ["User-Agent: FNF-Launcher", "Content-Type: application/json"]
	var err := http.request(server(main) + path, headers, method, JSON.stringify(body) if body != null else "")
	if err != OK:
		http.queue_free()
		return null
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return null
	return JSON.parse_string(res[3].get_string_from_utf8())
