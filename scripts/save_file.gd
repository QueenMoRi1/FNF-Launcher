class_name SaveFile
extends RefCounted
## Reads and writes HaxeFlixel save files (.sol, Haxe-serialized text) without
## losing anything: values are kept as a tree that remembers each value's exact
## type (object vs map, int vs float text...), so writing it back changes only
## what was edited. If a file uses something this doesn't understand, parse()
## returns null and the file is left alone.
##
## Nodes: {"t": type char, ...}
##   scalars n t f z k m p     {"t"}
##   i d                       {"t", "v": number text}
##   y (string)                {"t": "y", "v": String}   (R refs are resolved)
##   o b c (object/map/class)  {"t", "keys": [String], "vals": [node], "name"(c): node}
##   q (int map)               {"t": "q", "keys": [int text], "vals": [node]}
##   a l (array/list)          {"t", "items": [node]}    ("u" null runs: {"t": "u", "v": count})
##   s r (bytes/object ref)    {"t", "v": raw text}


static func parse(text: String):
	var r := _Parser.new(text)
	var node = r.value()
	return node if r.ok and r.pos == text.length() else null


static func dump(node: Dictionary) -> String:
	var out := PackedStringArray()
	_dump(node, out, {})
	return "".join(out)


static func load_file(path: String):
	return parse(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null


## Writes `node` to `path` (via a temp file, so a crash can't leave half a save).
static func save_file(path: String, node: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(dump(node))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK


## The value node for `key` in an object/map node, or null.
static func field(node, key: String):
	if not node is Dictionary or not node.get("t") in ["o", "b", "c"]:
		return null
	var i: int = node.keys.find(key)
	return node.vals[i] if i >= 0 else null


static func set_field(node: Dictionary, key: String, value: Dictionary) -> void:
	var i: int = node.keys.find(key)
	if i >= 0:
		node.vals[i] = value
	else:
		node.keys.append(key)
		node.vals.append(value)


static func int_node(n: int) -> Dictionary:
	return {"t": "z"} if n == 0 else {"t": "i", "v": str(n)}


static func string_node(s: String) -> Dictionary:
	return {"t": "y", "v": s}


static func bool_node(b: bool) -> Dictionary:
	return {"t": "t" if b else "f"}


## Int value of an i/z node, or `fallback`.
static func as_int(node, fallback := 0) -> int:
	if node is Dictionary and node.get("t") == "z":
		return 0
	if node is Dictionary and node.get("t") == "i":
		return int(node.v)
	return fallback


## Strings repeat as "R<n>" (n = order of first appearance), like Haxe's own
## serializer, so an untouched save is written back byte for byte.
static func _str(s: String, out: PackedStringArray, seen: Dictionary) -> void:
	if seen.has(s):
		out.append("R%d" % seen[s])
		return
	seen[s] = seen.size()
	# Haxe escapes like JavaScript's encodeURIComponent: ! ' ( ) * stay as they are.
	var enc := s.uri_encode().replace("%21", "!").replace("%27", "'").replace("%28", "(").replace("%29", ")").replace("%2A", "*")
	out.append("y%d:%s" % [enc.length(), enc])


static func _dump(node: Dictionary, out: PackedStringArray, seen: Dictionary) -> void:
	var t: String = node.t
	match t:
		"n", "t", "f", "z", "k", "m", "p":
			out.append(t)
		"i", "d", "s", "r":
			out.append(t + node.v)
		"u":
			out.append("u" + str(node.v))
		"y":
			_str(node.v, out, seen)
		"o", "b", "c":
			out.append(t)
			if t == "c":
				_dump(node.name, out, seen)
			for i in node.keys.size():
				_str(node.keys[i], out, seen)
				_dump(node.vals[i], out, seen)
			out.append("g" if t != "b" else "h")
		"q":
			out.append("q")
			for i in node.keys.size():
				out.append(":" + node.keys[i])
				_dump(node.vals[i], out, seen)
			out.append("h")
		"a", "l":
			out.append(t)
			for item in node.items:
				_dump(item, out, seen)
			out.append("h")


class _Parser:
	var text: String
	var pos := 0
	var ok := true
	var strings: Array[String] = []

	func _init(t: String) -> void:
		text = t

	func peek() -> String:
		return text[pos] if pos < text.length() else ""

	func number() -> String:
		var start := pos
		while pos < text.length() and "0123456789+-.eE".contains(text[pos]):
			pos += 1
		if pos == start:
			ok = false
		return text.substr(start, pos - start)

	func string_after_y() -> String:
		var colon := text.find(":", pos)
		if colon < 0:
			ok = false
			return ""
		var length := int(text.substr(pos, colon - pos))
		var s := text.substr(colon + 1, length).uri_decode()
		pos = colon + 1 + length
		strings.append(s)
		return s

	func key() -> String:
		# Object/map keys are strings: "y..." or a cached "R<n>".
		var v = value()
		if v is Dictionary and v.get("t") == "y":
			return v.v
		ok = false
		return ""

	func value():
		if not ok or pos >= text.length():
			ok = false
			return {"t": "n"}
		var c := text[pos]
		pos += 1
		match c:
			"n", "t", "f", "z", "k", "m", "p":
				return {"t": c}
			"i", "d":
				return {"t": c, "v": number()}
			"y":
				return {"t": "y", "v": string_after_y()}
			"R":
				var i := int(number())
				if i < 0 or i >= strings.size():
					ok = false
					return {"t": "n"}
				return {"t": "y", "v": strings[i]}
			"r":
				return {"t": "r", "v": number()}
			"s":
				var colon := text.find(":", pos)
				var length := int(text.substr(pos, colon - pos))
				var raw := text.substr(pos, colon - pos + 1 + length)
				pos = colon + 1 + length
				return {"t": "s", "v": raw}
			"o", "b", "c":
				var node := {"t": c, "keys": [], "vals": []}
				if c == "c":
					node.name = value()
				var end := "h" if c == "b" else "g"
				while ok and peek() != end:
					if peek() == "":
						ok = false
						break
					node.keys.append(key())
					node.vals.append(value())
				pos += 1
				return node
			"q":
				var node := {"t": "q", "keys": [], "vals": []}
				while ok and peek() == ":":
					pos += 1
					node.keys.append(number())
					node.vals.append(value())
				if peek() != "h":
					ok = false
				pos += 1
				return node
			"a", "l":
				var node := {"t": c, "items": []}
				while ok and peek() != "h":
					if peek() == "":
						ok = false
						break
					if peek() == "u":
						pos += 1
						node.items.append({"t": "u", "v": int(number())})
					else:
						node.items.append(value())
				pos += 1
				return node
		ok = false # enums, dates, exceptions, custom classes: not in FNF saves
		return {"t": "n"}
