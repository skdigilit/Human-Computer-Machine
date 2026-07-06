class_name CursorTexture
extends RefCounted

## Rasterises the SVG cursor art in cursors/ to a requested pixel size using
## the engine's DPITexture (instead of loading a fixed-size PNG, which goes
## blurry once the requested size no longer matches it). The click hotspot is
## derived from the rasterised pixels themselves rather than a hand-picked
## offset, so it can't drift out of sync with the artwork.

## How a cursor's hotspot should be derived from its rasterised pixels.
enum HotspotMode {
	TIP,    ## Topmost, then left-most opaque pixel — for pointing cursors.
	CENTER, ## Centre of the opaque pixels' bounding box — for grab cursors.
}

## Shared viewBox width/height of the cursor SVGs in cursors/.
const SVG_NATIVE_SIZE := 128.0

## A rasterised cursor: the texture plus the click hotspot within it (in
## raster pixels). Consumed by SoftwareCursor to draw the sprite pointer.
class Cursor:
	var texture: Texture2D
	var hotspot: Vector2

	func _init(p_texture: Texture2D, p_hotspot: Vector2) -> void:
		texture = p_texture
		hotspot = p_hotspot

## Loads the SVG at `svg_path` and rasterises it via DPITexture so it is
## exactly `pixel_size` pixels wide/tall, then derives its hotspot from the
## opaque pixels per `hotspot_mode`.
static func load_cursor(svg_path: String, pixel_size: float, hotspot_mode: HotspotMode) -> Cursor:
	var svg_source := FileAccess.get_file_as_string(svg_path)
	if svg_source.is_empty():
		push_warning("CursorTexture: missing SVG asset at %s." % svg_path)
		return null

	var texture: DPITexture = DPITexture.create_from_string(svg_source, pixel_size / SVG_NATIVE_SIZE)
	# The canvas renderer blends straight (unpremultiplied) alpha; leaving
	# premultiplication on darkens all anti-aliased edges into a grey fringe.
	texture.premult_alpha = false
	texture.fix_alpha_border = true
	var image := texture.get_image()
	return Cursor.new(texture, _find_hotspot(image, hotspot_mode))

## Scans the rasterised image's opaque pixels for the point hotspot_mode asks for.
static func _find_hotspot(image: Image, hotspot_mode: HotspotMode) -> Vector2:
	var min_pos := Vector2(image.get_width(), image.get_height())
	var max_pos := Vector2.ZERO
	var tip := Vector2(-1.0, -1.0)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.5:
				continue
			if tip.x < 0.0:
				tip = Vector2(x, y)
			min_pos.x = minf(min_pos.x, x)
			min_pos.y = minf(min_pos.y, y)
			max_pos.x = maxf(max_pos.x, x)
			max_pos.y = maxf(max_pos.y, y)
	if tip.x < 0.0:
		return Vector2.ZERO
	if hotspot_mode == HotspotMode.CENTER:
		return (min_pos + max_pos) / 2.0
	return tip
