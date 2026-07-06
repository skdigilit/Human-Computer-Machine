class_name SFSymbols
extends RefCounted

## Minimal SF Symbols PNG loader. Assets are generated like good-layout's
## GGSymbols helper: SF Symbol names map to PNG files with dots replaced by
## dashes, then black template pixels are recolored at load time.

const ICON_DIR := "res://icons/"

static var _cache: Dictionary = {}

static func slug(symbol: String) -> String:
	return symbol.replace(".", "-")

static func texture(symbol: String, tint: Color = Color.BLACK) -> Texture2D:
	if symbol.is_empty():
		return null
	var key := "%s@%s" % [symbol, tint.to_html()]
	if _cache.has(key):
		return _cache[key]

	var path := ICON_DIR + slug(symbol) + ".png"
	var base := _load_texture(path)
	if base == null:
		push_warning("SFSymbols: missing icon asset for '%s' at %s." % [symbol, path])
		return null

	var image := base.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.0:
				image.set_pixel(x, y, Color(tint.r, tint.g, tint.b, alpha))

	var recolored := ImageTexture.create_from_image(image)
	_cache[key] = recolored
	return recolored

static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)
