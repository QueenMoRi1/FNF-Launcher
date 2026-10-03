class_name GameBanana
extends Node
## GameBanana lookups for FNF mods: search, name matching, and art downloads.
## Results are {id, name, url, art_url, thumb_url}. Network errors return empty.

const API := "https://gamebanana.com/apiv11"
const FNF_GAME_ID := 8694
const CACHE_DIR := "user://gb_art"
const MATCH_THRESHOLD := 0.6
## Words that say nothing about which mod it is.
const NOISE := ["fnf", "friday", "night", "funkin", "vs", "the", "mod", "a", "of", "and", "for"]

## url -> Texture2D, so thumbnails/art are only loaded once per session
var _textures := {}


func search(query: String) -> Array:
	var url := "%s/Util/Search/Results?_sModelName=Mod&_sOrder=popularity&_idGameRow=%d&_sSearchString=%s&_nPage=1" \
		% [API, FNF_GAME_ID, query.uri_encode()]
	var data = await _get_json(url)
	var out := []
	if data is Dictionary:
		for record in data.get("_aRecords", []):
			out.append(_parse(record))
	return out


func get_mod(id: int) -> Dictionary:
	var data = await _get_json("%s/Mod/%d?_csvProperties=_sName,_aPreviewMedia,_sProfileUrl" % [API, id])
	if not (data is Dictionary and data.has("_sName")):
		return {}
	data["_idRow"] = id
	return _parse(data)


## Like get_mod, plus "files": [{file, size, url, date}] (the mod's downloads;
## date = when the file was uploaded, unix time).
func get_mod_files(id: int) -> Dictionary:
	var data = await _get_json("%s/Mod/%d?_csvProperties=_sName,_aPreviewMedia,_sProfileUrl,_aFiles" % [API, id])
	if not (data is Dictionary and data.has("_sName")):
		return {}
	data["_idRow"] = id
	var mod := _parse(data)
	mod.files = []
	for f in data.get("_aFiles", []):
		mod.files.append({"file": f.get("_sFile", ""), "size": int(f.get("_nFilesize", 0)), "url": f.get("_sDownloadUrl", ""),
			"date": int(f.get("_tsDateAdded", 0))})
	return mod


## Finds the mod by name. Returns {} if nothing is a confident match.
func auto_match(game_name: String) -> Dictionary:
	var words := normalize(game_name)
	if words.is_empty():
		return {}
	var best := {}
	var best_score := 0.0
	for result in (await search(" ".join(words))).slice(0, 15):
		var score := _overlap(words, normalize(result.name))
		if score > best_score:
			best_score = score
			best = result
	return best if best_score >= MATCH_THRESHOLD else {}


## Downloads (once) and loads an image. Mipmapped so skins can blur it.
func fetch_image(url: String) -> Texture2D:
	if url == "":
		return null
	if _textures.has(url):
		return _textures[url]
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var ext := url.get_extension().to_lower()
	var path := CACHE_DIR.path_join(url.md5_text() + "." + (ext if ext in ["jpg", "jpeg", "png", "webp"] else "jpg"))
	if not FileAccess.file_exists(path):
		var http := HTTPRequest.new()
		http.timeout = 20
		http.download_file = path
		add_child(http)
		if http.request(url) != OK:
			http.queue_free()
			return null
		var res: Array = await http.request_completed
		http.queue_free()
		if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
			DirAccess.remove_absolute(path)
			return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[url] = tex
	return tex


## "Friday Night Funkin': Soft V2" -> ["soft"]
static func normalize(text: String) -> PackedStringArray:
	var clean := RegEx.create_from_string("[^a-z0-9 ]").sub(text.to_lower().replace("'", ""), " ", true)
	var version := RegEx.create_from_string("^v?\\d+(\\.\\d+)*[a-z]?$")
	var out := PackedStringArray()
	for word in clean.split(" ", false):
		if not word in NOISE and not version.search(word):
			out.append(word)
	return out


## Extracts the mod id from a gamebanana.com/mods/<id> link, or -1.
static func id_from_url(url: String) -> int:
	var m := RegEx.create_from_string("gamebanana\\.com/mods/(\\d+)").search(url)
	return m.get_string(1).to_int() if m else -1


static func _overlap(a: PackedStringArray, b: PackedStringArray) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	var shared := 0
	for word in a:
		if word in b:
			shared += 1
	return float(shared) / maxi(a.size(), b.size())


static func _parse(r: Dictionary) -> Dictionary:
	var art := ""
	var thumb := ""
	var images: Array = r.get("_aPreviewMedia", {}).get("_aImages", []) if r.get("_aPreviewMedia") is Dictionary else []
	if not images.is_empty():
		var img: Dictionary = images[0]
		var base: String = img.get("_sBaseUrl", "")
		art = base + "/" + img.get("_sFile", "")
		thumb = base + "/" + img.get("_sFile220", img.get("_sFile", ""))
	return {
		"id": int(r.get("_idRow", 0)),
		"name": r.get("_sName", ""),
		"url": r.get("_sProfileUrl", ""),
		"art_url": art,
		"thumb_url": thumb,
	}


func _get_json(url: String) -> Variant:
	var http := HTTPRequest.new()
	http.timeout = 12
	add_child(http)
	if http.request(url, ["User-Agent: FNF-Launcher"]) != OK:
		http.queue_free()
		return null
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return null
	return JSON.parse_string(res[3].get_string_from_utf8())
