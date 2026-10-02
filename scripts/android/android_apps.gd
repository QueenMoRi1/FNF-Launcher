class_name AndroidApps
extends RefCounted
## Android side of the library: finds installed Friday Night Funkin' apps, reads
## their icons and instrumentals straight out of their APKs (an APK is a zip),
## and launches them. Uses Godot's AndroidRuntime + JavaClassWrapper, so no
## custom Java plugin is needed.

## Songs inside an APK are stored as "apk://<apk path>!<entry path>".
const APK_SCHEME := "apk://"
## Package prefixes that are never FNF games (saves opening their APKs).
const SKIP_PREFIXES := ["android", "com.android.", "com.google.", "org.lineageos.", "com.qualcomm.", "org.chromium."]
const ICON_DENSITIES := ["xxxhdpi", "xxhdpi", "xhdpi", "hdpi", "mdpi"]
const SELF_PACKAGE := "com.orangentertainment.fnflauncher"


static func is_android() -> bool:
	return OS.get_name() == "Android"


static func _runtime() -> Object:
	return Engine.get_singleton("AndroidRuntime") if Engine.has_singleton("AndroidRuntime") else null


## Rescans installed apps. `known` is the current library (key -> entry); user
## edits (name, GameBanana page, icon) are kept. Returns the new library.
static func scan(known: Dictionary) -> Dictionary:
	var out := {}
	var apps := installed_apps()
	for app in apps:
		var key: String = "android:" + app.package
		var entry: Dictionary = known.get(key, {})
		var size := _file_size(app.apk)
		if entry.get("apk", "") != app.apk or int(entry.get("apk_size", -1)) != size:
			# New or updated app: (re)inspect its APK.
			var info := inspect_apk(app.apk, app.package, app.label)
			if info.is_empty():
				continue
			if entry.is_empty():
				entry = {"name": app.label, "icon_override": "", "slug": app.package, "prefix": "", "exe": ""}
			entry.merge(info, true)
			entry.apk_size = size
		entry.package = app.package
		entry.apk = app.apk
		out[key] = entry
	print("[AndroidApps] %d launchable apps checked, %d FNF games found" % [apps.size(), out.size()])
	return out


## [{package, label, apk}] for every launchable, non-system app.
static func installed_apps() -> Array:
	var runtime := _runtime()
	if runtime == null:
		return []
	var context = runtime.getApplicationContext()
	var pm = context.getPackageManager()
	var apps = pm.getInstalledApplications(0)
	var out := []
	if apps == null:
		print("[AndroidApps] getInstalledApplications returned nothing")
		return out
	print("[AndroidApps] %d installed packages" % apps.size())
	for i in apps.size():
		var app_info = apps.get(i)
		var package := _package_name(str(app_info.toString()))
		if package == "" or package == SELF_PACKAGE or _skipped(package) or _launch_intent(pm, package) == null:
			continue
		var package_context = context.createPackageContext(package, 0)
		if package_context == null:
			continue
		out.append({
			"package": package,
			"label": str(app_info.loadLabel(pm)),
			"apk": str(package_context.getPackageCodePath()),
		})
	return out


## Opens an APK and decides if it's an FNF game. Returns {songs, icon_entry}
## (plus "fnf": true) or {} if it isn't one.
static func inspect_apk(apk: String, package: String, label: String) -> Dictionary:
	var files := list_apk(apk)
	if files.is_empty():
		print("[AndroidApps] couldn't read %s (%s)" % [package, apk])
		return {}
	var songs := []
	var by_size := {}
	var has_preload := false
	var has_shared := false
	var has_assets := false
	var icons := {} # density -> entry
	for f in files:
		var lower := f.to_lower()
		if lower.begins_with("assets/"):
			has_assets = true
			has_preload = has_preload or lower.contains("/preload/")
			has_shared = has_shared or lower.contains("/shared/")
		var base := lower.get_file().get_basename()
		var ext := lower.get_extension()
		if (ext == "ogg" or ext == "mp3") and (base == "inst" or base.begins_with("inst-") or base.begins_with("inst_")):
			var folder := f.get_base_dir().get_file().to_lower()
			if folder in Library.SKIP_SONGS:
				continue
			var title := Library.song_title(f)
			if not by_size.has(title):
				by_size[title] = true
				songs.append({"title": title, "path": APK_SCHEME + apk + "!" + f})
		elif ext == "png" and lower.begins_with("res/"):
			for density in ICON_DENSITIES:
				if lower.contains("-" + density) and (base in ["ic_launcher", "icon", "ic_launcher_foreground"]):
					if not icons.has(density) or base == "ic_launcher":
						icons[density] = f
	var named_fnf := (package + " " + label).to_lower().contains("funkin") or (package + " " + label).to_lower().contains("fnf")
	if songs.is_empty() and not (has_preload and has_shared) and not (named_fnf and has_assets):
		return {}
	var icon := ""
	for density in ICON_DENSITIES:
		if icons.has(density):
			icon = icons[density]
			break
	songs.sort_custom(func(a, b): return a.title.naturalnocasecmp_to(b.title) < 0)
	return {"fnf": true, "songs": songs, "icon_entry": icon}


## Every file inside an APK (or any zip).
## Godot can only open files in the app's own storage on Android, so other
## apps' APKs are read with Java's java.util.zip instead (Android lets any app
## read installed APKs). Godot's reader is tried first; it works on desktop.
static func list_apk(apk: String) -> PackedStringArray:
	var zip := ZIPReader.new()
	if zip.open(apk) == OK:
		var files := zip.get_files()
		zip.close()
		return files
	var java_zip = _java_zip(apk)
	if java_zip == null:
		return PackedStringArray()
	var files := PackedStringArray()
	var entries = java_zip.entries()
	while entries.hasMoreElements():
		files.append(str(entries.nextElement().getName()))
	java_zip.close()
	return files


## Reads one file out of an APK (or any zip).
static func read_from_apk(apk: String, entry: String) -> PackedByteArray:
	var zip := ZIPReader.new()
	if zip.open(apk) == OK:
		var data := zip.read_file(entry)
		zip.close()
		return data
	var java_zip = _java_zip(apk)
	if java_zip == null:
		return PackedByteArray()
	var data := PackedByteArray()
	var zip_entry = java_zip.getEntry(entry)
	if zip_entry != null:
		var input = java_zip.getInputStream(zip_entry)
		var output = JavaClassWrapper.wrap("java.io.ByteArrayOutputStream").ByteArrayOutputStream()
		JavaClassWrapper.wrap("android.os.FileUtils").copy(input, output) # Android 10+
		input.close()
		data = output.toByteArray()
	java_zip.close()
	return data


static func _java_zip(apk: String):
	if _runtime() == null:
		return null
	return JavaClassWrapper.wrap("java.util.zip.ZipFile").ZipFile(apk)


## "apk://<apk>!<entry>" -> [apk, entry]
static func split_apk_path(path: String) -> PackedStringArray:
	var rest := path.trim_prefix(APK_SCHEME)
	var cut := rest.find("!")
	return PackedStringArray([rest.left(cut), rest.substr(cut + 1)]) if cut > 0 else PackedStringArray()


## The app's icon: from the APK if it has a plain PNG one, else drawn by Android.
static func load_icon(entry: Dictionary) -> Image:
	var icon_entry: String = entry.get("icon_entry", "")
	if icon_entry != "":
		var img := Image.new()
		if img.load_png_from_buffer(read_from_apk(entry.apk, icon_entry)) == OK:
			return img
	return _icon_from_package_manager(entry.package)


## Asks Android to draw the app's icon into a bitmap and hands back the PNG.
static func _icon_from_package_manager(package: String) -> Image:
	var runtime := _runtime()
	if runtime == null:
		return null
	var pm = runtime.getApplicationContext().getPackageManager()
	var drawable = pm.getApplicationIcon(package)
	if drawable == null:
		return null
	var Bitmap = JavaClassWrapper.wrap("android.graphics.Bitmap")
	var BitmapConfig = JavaClassWrapper.wrap("android.graphics.Bitmap$Config")
	var CompressFormat = JavaClassWrapper.wrap("android.graphics.Bitmap$CompressFormat")
	var Canvas = JavaClassWrapper.wrap("android.graphics.Canvas")
	var Stream = JavaClassWrapper.wrap("java.io.ByteArrayOutputStream")
	var bitmap = Bitmap.createBitmap(192, 192, BitmapConfig.ARGB_8888)
	drawable.setBounds(0, 0, 192, 192)
	drawable.draw(Canvas.Canvas(bitmap))
	var stream = Stream.ByteArrayOutputStream()
	bitmap.compress(CompressFormat.PNG, 100, stream)
	var img := Image.new()
	return img if img.load_png_from_buffer(stream.toByteArray()) == OK else null


## Starts the app. Returns false if Android couldn't.
static func launch(package: String) -> bool:
	var runtime := _runtime()
	if runtime == null:
		return false
	var activity = runtime.getActivity()
	var intent = _launch_intent(activity.getPackageManager(), package)
	if intent == null:
		return false
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(func(): activity.startActivity(intent)))
	return true


## Phone apps have a normal launch intent; Android TV apps have a "leanback" one.
static func _launch_intent(pm, package: String):
	var intent = pm.getLaunchIntentForPackage(package)
	return intent if intent != null else pm.getLeanbackLaunchIntentForPackage(package)


## "ApplicationInfo{1a2b3c4 com.example.game}" -> "com.example.game"
static func _package_name(info: String) -> String:
	var m := RegEx.create_from_string("\\{\\S+ ([A-Za-z0-9_.]+)\\}").search(info)
	return m.get_string(1) if m else ""


static func _skipped(package: String) -> bool:
	for prefix in SKIP_PREFIXES:
		if package == prefix or package.begins_with(prefix):
			return true
	return false


static func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else -1
