class_name SteamFriends
extends RefCounted
## Reads your Steam account and friends list from the local Steam client's
## files (no API key or login needed).

const STEAMID64_BASE := 76561197960265728
const AVATAR_URL := "https://avatars.steamstatic.com/%s_medium.jpg"


## {id: account id string, name} for the most recently logged-in account, or {}.
static func me() -> Dictionary:
	for root in Proton.steam_roots():
		var users: Dictionary = parse_vdf_file(root.path_join("config/loginusers.vdf")).get("users", {})
		for id64 in users:
			var user: Dictionary = users[id64]
			if str(user.get("MostRecent", "0")) == "1" or users.size() == 1:
				var id := str(int(id64) - STEAMID64_BASE)
				return {"id": id, "name": user.get("PersonaName", "")}
	return {}


## [{id, name, avatar_url}] for every friend Steam has cached locally.
static func friends() -> Array:
	var account := me()
	if account.is_empty():
		return []
	for root in Proton.steam_roots():
		var path := root.path_join("userdata/%s/config/localconfig.vdf" % account.id)
		if not FileAccess.file_exists(path):
			continue
		var block: Dictionary = parse_vdf_file(path).get("UserLocalConfigStore", {}).get("friends", {})
		var out := []
		for id in block:
			var friend = block[id]
			if not (friend is Dictionary and id.is_valid_int()) or id == account.id:
				continue
			if friend.get("name", "") == "":
				continue
			var avatar: String = friend.get("avatar", "")
			out.append({
				"id": id,
				"name": friend.name,
				"avatar_url": AVATAR_URL % avatar if avatar.length() == 40 else "",
			})
		out.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
		return out
	return []


static func parse_vdf_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return parse_vdf(FileAccess.get_file_as_string(path))


## Minimal parser for Valve's KeyValues text format ("key" "value" / "key" { ... }).
static func parse_vdf(text: String) -> Dictionary:
	var tokens := PackedStringArray()
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if c == "\"":
			var j := i + 1
			var token := ""
			while j < n and text[j] != "\"":
				if text[j] == "\\" and j + 1 < n:
					j += 1
				token += text[j]
				j += 1
			tokens.append("s" + token)
			i = j + 1
		elif c == "{" or c == "}":
			tokens.append(c)
			i += 1
		elif c == "/" and i + 1 < n and text[i + 1] == "/":
			while i < n and text[i] != "\n":
				i += 1
		else:
			i += 1
	var stack: Array[Dictionary] = [{}]
	var key := ""
	for token in tokens:
		if token == "{":
			var child := {}
			stack.back()[key] = child
			stack.append(child)
			key = ""
		elif token == "}":
			if stack.size() > 1:
				stack.pop_back()
		elif key == "":
			key = token.substr(1)
		else:
			stack.back()[key] = token.substr(1)
			key = ""
	return stack[0]
