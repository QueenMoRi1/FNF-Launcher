class_name Keybinds
extends RefCounted
## One set of note keys for every mod (Settings > KEYBINDS). Before a mod
## starts, its saved controls are rewritten to use them. Only the main key of
## each note changes; the second one (usually the arrows) stays.
##
## Mods only save their controls after running once, so new mods pick the keys
## up from their second launch. Formats understood:
##   Psych Engine 0.6+  controls_v2.sol  customControls: {note_left: [key, key], ...}
##   Psych Engine 0.4/0.5  controls.sol  customControls: [left, left2, down, down2, ...]
##   Kade Engine        funkin.sol      leftBind / downBind / upBind / rightBind: "D"
## Anything else is left alone.

const DEFAULT := ["D", "F", "J", "K"]
const PSYCH_NAMES := ["note_left", "note_down", "note_up", "note_right"]
const KADE_NAMES := ["leftBind", "downBind", "upBind", "rightBind"]

## FlxKey name -> FlxKey code (what the saves store).
const FLX := {
	"LEFT": 37, "UP": 38, "RIGHT": 39, "DOWN": 40, "SPACE": 32,
	"SEMICOLON": 186, "COMMA": 188, "PERIOD": 190, "SLASH": 191, "QUOTE": 222,
	"LBRACKET": 219, "RBRACKET": 221,
	"ZERO": 48, "ONE": 49, "TWO": 50, "THREE": 51, "FOUR": 52,
	"FIVE": 53, "SIX": 54, "SEVEN": 55, "EIGHT": 56, "NINE": 57,
}
const DIGITS := ["ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE"]
const SHOWN := {"LEFT": "←", "UP": "↑", "RIGHT": "→", "DOWN": "↓", "SPACE": "SPACE", "SEMICOLON": ";",
	"COMMA": ",", "PERIOD": ".", "SLASH": "/", "QUOTE": "'", "LBRACKET": "[", "RBRACKET": "]"}


## A Godot key -> FlxKey name, or "" if FNF mods can't use it.
static func name_for(keycode: int) -> String:
	if keycode >= KEY_A and keycode <= KEY_Z:
		return char(keycode)
	if keycode >= KEY_0 and keycode <= KEY_9:
		return DIGITS[keycode - KEY_0]
	match keycode:
		KEY_LEFT: return "LEFT"
		KEY_UP: return "UP"
		KEY_RIGHT: return "RIGHT"
		KEY_DOWN: return "DOWN"
		KEY_SPACE: return "SPACE"
		KEY_SEMICOLON: return "SEMICOLON"
		KEY_COMMA: return "COMMA"
		KEY_PERIOD: return "PERIOD"
		KEY_SLASH: return "SLASH"
		KEY_APOSTROPHE: return "QUOTE"
		KEY_BRACKETLEFT: return "LBRACKET"
		KEY_BRACKETRIGHT: return "RBRACKET"
	return ""


## FlxKey name -> FlxKey code ("D" -> 68).
static func code_for(flx_name: String) -> int:
	if flx_name.length() == 1 and flx_name >= "A" and flx_name <= "Z":
		return flx_name.unicode_at(0)
	return FLX.get(flx_name, -1)


## How a key is shown on screen ("D", "←", ";", "7").
static func shown(flx_name: String) -> String:
	if flx_name in DIGITS:
		return str(DIGITS.find(flx_name))
	return SHOWN.get(flx_name, flx_name)


## The keys from settings, or the default D F J K.
static func keys_from(settings: Dictionary) -> Array:
	var k = settings.get("keybinds", {}).get("keys", DEFAULT)
	return k if k is Array and k.size() == 4 else DEFAULT.duplicate()


static func enabled(settings: Dictionary) -> bool:
	return settings.get("keybinds", {}).get("on", false)


## Writes `keys` (4 FlxKey names) into the mod's saved controls.
## Returns how many save files were changed.
static func apply(entry: Dictionary, keys: Array) -> int:
	var codes := keys.map(func(k): return code_for(k))
	if codes.size() != 4 or -1 in codes:
		return 0
	var changed := 0
	for path in ModSaves.sol_files(entry):
		var root = SaveFile.load_file(path)
		if not root is Dictionary or not root.get("t") in ["o", "b", "c"]:
			continue
		if _apply_to(root, keys, codes):
			if SaveFile.save_file(path, root):
				changed += 1
	return changed


## Changes the controls in one parsed save. Returns true if anything changed.
static func _apply_to(root: Dictionary, keys: Array, codes: Array) -> bool:
	var before := SaveFile.dump(root)
	var custom = SaveFile.field(root, "customControls")
	if custom is Dictionary:
		if custom.t in ["b", "o"]:
			# Psych 0.6+: note_left -> [main, alt]
			for i in 4:
				var binds = SaveFile.field(custom, PSYCH_NAMES[i])
				if binds is Dictionary and binds.t == "a" and not binds.items.is_empty():
					binds.items[0] = SaveFile.int_node(codes[i])
		elif custom.t == "a" and custom.items.size() >= 8 and custom.items.size() % 2 == 0:
			# Psych 0.4/0.5: pairs, the four note pairs first.
			if custom.items.slice(0, 8).all(func(n): return n is Dictionary and n.t in ["i", "z"]):
				for i in 4:
					custom.items[i * 2] = SaveFile.int_node(codes[i])
	var kade := KADE_NAMES.all(func(n):
		var v = SaveFile.field(root, n)
		return v is Dictionary and v.t == "y")
	if kade:
		for i in 4:
			SaveFile.set_field(root, KADE_NAMES[i], SaveFile.string_node(keys[i]))
	return SaveFile.dump(root) != before
