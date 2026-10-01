class_name IconLoader
extends RefCounted
## Finds a game's icon: user override > .ico/icon*.png in folder > icon embedded
## in the exe > bundled FNF face icon. Godot can't read .ico, so it's decoded here.

const CACHE_DIR := "user://icons"
const FALLBACK := "res://assets/funkin/icon-face.png"
const RT_ICON := 3
const RT_GROUP_ICON := 14


static func load_icon(folder: String, entry: Dictionary) -> Image:
	var img: Image = null
	if entry.get("icon_override", "") != "":
		img = load_image_file(entry.icon_override)
	if img == null:
		img = _from_folder(folder)
	if img == null and entry.get("exe", "") != "":
		img = _from_exe_cached(entry.exe)
	if img == null:
		img = fallback()
	return img


static func fallback() -> Image:
	# icon-face.png is a 2-frame strip (normal, losing); keep the left frame.
	var img: Image = load(FALLBACK).get_image()
	return img.get_region(Rect2i(0, 0, img.get_height(), img.get_height()))


## Average opaque color, brightened for use as a background tint.
static func tint_color(img: Image) -> Color:
	var small := img.duplicate() as Image
	small.convert(Image.FORMAT_RGBA8)
	small.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	var sum := Color(0, 0, 0, 0)
	var weight := 0.0
	for y in 16:
		for x in 16:
			var c := small.get_pixel(x, y)
			sum += Color(c.r, c.g, c.b) * c.a
			weight += c.a
	if weight < 0.01:
		return Color("9271fd")
	var avg := sum / weight
	return Color.from_hsv(avg.h, clampf(avg.s, 0.3, 0.75), 0.95)


static func load_image_file(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	if path.get_extension().to_lower() == "ico":
		return decode_ico(FileAccess.get_file_as_bytes(path))
	var img := Image.new()
	return img if img.load(path) == OK else null


static func _from_folder(folder: String) -> Image:
	var d := DirAccess.open(folder)
	if d == null:
		return null
	var pngs: Array[String] = []
	for f in d.get_files():
		var lower := f.to_lower()
		if lower.ends_with(".ico"):
			var img := load_image_file(folder.path_join(f))
			if img:
				return img
		elif lower.begins_with("icon") and lower.ends_with(".png"):
			pngs.append(folder.path_join(f))
	for p in pngs:
		var img := load_image_file(p)
		if img:
			return img
	return null


static func _from_exe_cached(exe: String) -> Image:
	if not FileAccess.file_exists(exe):
		return null
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var key := "%s_%d" % [exe.md5_text(), FileAccess.get_modified_time(exe)]
	var png := CACHE_DIR.path_join(key + ".png")
	var none := CACHE_DIR.path_join(key + ".none")
	if FileAccess.file_exists(png):
		return Image.load_from_file(png)
	if FileAccess.file_exists(none):
		return null
	var img := extract_exe_icon(exe)
	if img:
		img.save_png(png)
	else:
		FileAccess.open(none, FileAccess.WRITE)
	return img


# --- PE resource parsing -----------------------------------------------------

## Reads the largest icon from a Windows exe's .rsrc section.
static func extract_exe_icon(exe: String) -> Image:
	var f := FileAccess.open(exe, FileAccess.READ)
	if f == null or f.get_length() < 0x40:
		return null
	f.seek(0x3C)
	var pe := f.get_32()
	if pe + 24 > f.get_length():
		return null
	f.seek(pe)
	if f.get_32() != 0x00004550: # "PE\0\0"
		return null
	f.get_16() # machine
	var num_sections := f.get_16()
	f.seek(pe + 20)
	var opt_size := f.get_16()
	var opt := pe + 24
	f.seek(opt)
	var magic := f.get_16()
	var dirs := opt + (112 if magic == 0x20b else 96)
	f.seek(dirs + 2 * 8) # resource table is data directory #2
	var rsrc_rva := f.get_32()
	if rsrc_rva == 0:
		return null

	var data := PackedByteArray()
	var sect_va := 0
	for i in num_sections:
		f.seek(opt + opt_size + i * 40 + 8)
		var vsize := f.get_32()
		var va := f.get_32()
		var raw_size := f.get_32()
		var raw_ptr := f.get_32()
		if rsrc_rva >= va and rsrc_rva < va + maxi(vsize, raw_size):
			f.seek(raw_ptr)
			data = f.get_buffer(raw_size)
			sect_va = va
			break
	if data.is_empty():
		return null
	var root := rsrc_rva - sect_va

	var groups := _find_dir(data, root, root, RT_GROUP_ICON)
	var icons := _find_dir(data, root, root, RT_ICON)
	if groups < 0 or icons < 0:
		return null
	var group := _first_leaf(data, root, groups)
	if group.is_empty():
		return null
	var grp := _slice_rva(data, sect_va, group)

	# GRPICONDIR: reserved, type, count, then 14-byte entries ending in a u16 id.
	var best_id := -1
	var best_score := -1
	var count := grp.decode_u16(4) if grp.size() >= 6 else 0
	for i in count:
		var e := 6 + i * 14
		if e + 14 > grp.size():
			break
		var w := grp[e] if grp[e] != 0 else 256
		var score := w * 100 + grp.decode_u16(e + 6)
		if score > best_score:
			best_score = score
			best_id = grp.decode_u16(e + 12)
	if best_id < 0:
		return null

	var icon_dir := _find_dir(data, root, icons, best_id)
	if icon_dir < 0:
		return null
	var leaf := _first_leaf(data, root, icon_dir)
	if leaf.is_empty():
		return null
	return _decode_entry(_slice_rva(data, sect_va, leaf))


## Returns the subdirectory offset for entry `id` in the directory at `dir`, or -1.
static func _find_dir(data: PackedByteArray, root: int, dir: int, id: int) -> int:
	if dir + 16 > data.size():
		return -1
	var count := data.decode_u16(dir + 12) + data.decode_u16(dir + 14)
	for i in count:
		var e := dir + 16 + i * 8
		if e + 8 > data.size():
			return -1
		var name := data.decode_u32(e)
		var off := data.decode_u32(e + 4)
		if (name & 0x80000000) == 0 and name == id and (off & 0x80000000) != 0:
			return root + (off & 0x7FFFFFFF)
	return -1


## Walks down the first entry of each level to a data entry. Returns [rva, size].
static func _first_leaf(data: PackedByteArray, root: int, dir: int) -> Array:
	for _depth in 4:
		if dir + 24 > data.size():
			return []
		var off := data.decode_u32(dir + 16 + 4)
		if (off & 0x80000000) != 0:
			dir = root + (off & 0x7FFFFFFF)
		else:
			var leaf := root + off
			if leaf + 8 > data.size():
				return []
			return [data.decode_u32(leaf), data.decode_u32(leaf + 4)]
	return []


static func _slice_rva(data: PackedByteArray, sect_va: int, leaf: Array) -> PackedByteArray:
	var start: int = leaf[0] - sect_va
	if start < 0 or start >= data.size():
		return PackedByteArray()
	return data.slice(start, mini(start + leaf[1], data.size()))


# --- ICO decoding ------------------------------------------------------------

static func decode_ico(bytes: PackedByteArray) -> Image:
	if bytes.size() < 6 or bytes.decode_u16(2) != 1:
		return null
	var best_off := -1
	var best_len := 0
	var best_score := -1
	for i in bytes.decode_u16(4):
		var e := 6 + i * 16
		if e + 16 > bytes.size():
			break
		var w := bytes[e] if bytes[e] != 0 else 256
		var score := w * 100 + bytes.decode_u16(e + 6)
		if score > best_score:
			best_score = score
			best_len = bytes.decode_u32(e + 8)
			best_off = bytes.decode_u32(e + 12)
	if best_off < 0 or best_off >= bytes.size():
		return null
	return _decode_entry(bytes.slice(best_off, best_off + best_len))


## An icon entry is either a PNG or a headerless BMP (DIB) with a doubled height.
static func _decode_entry(d: PackedByteArray) -> Image:
	if d.size() < 8:
		return null
	if d[0] == 0x89 and d[1] == 0x50 and d[2] == 0x4E and d[3] == 0x47:
		var img := Image.new()
		return img if img.load_png_from_buffer(d) == OK else null
	return _decode_dib(d)


static func _decode_dib(d: PackedByteArray) -> Image:
	if d.size() < 40:
		return null
	var hdr := d.decode_u32(0)
	var w := d.decode_s32(4)
	var h := absi(d.decode_s32(8)) / 2
	var bpp := d.decode_u16(14)
	if d.decode_u32(16) != 0 or w <= 0 or h <= 0 or not bpp in [1, 4, 8, 24, 32]:
		return null
	var pal_count := 0
	if bpp <= 8:
		pal_count = d.decode_u32(32) if d.decode_u32(32) > 0 else 1 << bpp
	var pal := hdr
	var xor := pal + pal_count * 4
	var xor_stride := (w * bpp + 31) / 32 * 4
	var mask := xor + xor_stride * h
	var mask_stride := (w + 31) / 32 * 4
	if d.size() < mask:
		return null
	var has_mask := d.size() >= mask + mask_stride * h

	var px := PackedByteArray()
	px.resize(w * h * 4)
	var max_alpha := 0
	for y in h:
		var row := xor + (h - 1 - y) * xor_stride
		for x in w:
			var o := (y * w + x) * 4
			var p: int
			if bpp == 32:
				p = row + x * 4
				px[o + 3] = d[p + 3]
				max_alpha = maxi(max_alpha, d[p + 3])
			elif bpp == 24:
				p = row + x * 3
			else:
				var bit := x * bpp
				var idx := (d[row + bit / 8] >> (8 - bpp - bit % 8)) & ((1 << bpp) - 1)
				p = pal + idx * 4
			px[o] = d[p + 2]
			px[o + 1] = d[p + 1]
			px[o + 2] = d[p]

	# Without real alpha, transparency comes from the 1bpp AND mask.
	if bpp != 32 or max_alpha == 0:
		for y in h:
			var mrow := mask + (h - 1 - y) * mask_stride
			for x in w:
				var hidden := has_mask and ((d[mrow + x / 8] >> (7 - x % 8)) & 1) == 1
				px[(y * w + x) * 4 + 3] = 0 if hidden else 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)
