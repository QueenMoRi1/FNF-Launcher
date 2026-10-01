class_name Alphabet
extends RefCounted
## FNF bold Alphabet text built from alphabet.png.
## Glyph regions are the "<letter> bold0000" frames from alphabet.xml.

const GLYPHS := {
	"A": Rect2(219, 141, 54, 67),
	"B": Rect2(457, 141, 46, 70),
	"C": Rect2(665, 141, 55, 66),
	"D": Rect2(904, 141, 53, 67),
	"E": Rect2(116, 221, 43, 66),
	"F": Rect2(310, 221, 43, 67),
	"G": Rect2(508, 221, 54, 70),
	"H": Rect2(742, 221, 45, 66),
	"I": Rect2(935, 221, 43, 64),
	"J": Rect2(145, 301, 54, 70),
	"K": Rect2(371, 301, 44, 69),
	"L": Rect2(569, 301, 41, 66),
	"M": Rect2(759, 301, 56, 63),
	"N": Rect2(0, 381, 45, 65),
	"O": Rect2(194, 381, 50, 69),
	"P": Rect2(414, 381, 46, 70),
	"Q": Rect2(616, 381, 52, 67),
	"R": Rect2(842, 381, 47, 66),
	"S": Rect2(50, 461, 49, 66),
	"T": Rect2(264, 461, 44, 64),
	"U": Rect2(476, 461, 44, 59),
	"V": Rect2(680, 461, 54, 66),
	"W": Rect2(908, 461, 58, 63),
	"X": Rect2(180, 537, 55, 67),
	"Y": Rect2(412, 537, 54, 69),
	"Z": Rect2(644, 537, 52, 65),
}
const BASE_HEIGHT := 70.0

static var _atlas: Texture2D
static var _frames := {}


## Builds a row of glyphs about `height` px tall. Non-letters fall back to VCR.
static func make_text(text: String, height := 70.0) -> HBoxContainer:
	var s := height / BASE_HEIGHT
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", int(2 * s))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in text.to_upper():
		var glyph := _glyph(ch)
		if glyph:
			var rect := TextureRect.new()
			rect.texture = glyph
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			rect.custom_minimum_size = glyph.region.size * s
			rect.size_flags_vertical = Control.SIZE_SHRINK_END
			box.add_child(rect)
		elif ch == " ":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(36 * s, 0)
			box.add_child(gap)
		else:
			var label := Label.new()
			label.text = ch
			label.add_theme_font_size_override("font_size", int(height * 0.85))
			label.add_theme_constant_override("outline_size", int(10 * s))
			label.size_flags_vertical = Control.SIZE_SHRINK_END
			box.add_child(label)
	return box


static func _glyph(ch: String) -> AtlasTexture:
	if not GLYPHS.has(ch):
		return null
	if not _frames.has(ch):
		if _atlas == null:
			_atlas = load("res://assets/funkin/alphabet.png")
		var tex := AtlasTexture.new()
		tex.atlas = _atlas
		tex.region = GLYPHS[ch]
		_frames[ch] = tex
	return _frames[ch]
