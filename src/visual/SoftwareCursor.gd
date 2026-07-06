class_name SoftwareCursor
extends CanvasLayer

## Software mouse cursor: hides the OS pointer while this node is in the tree
## and draws the cursor art as a Sprite2D that follows the mouse instead.
##
## Why not Input.set_custom_mouse_cursor()? Hardware cursors are handed to the
## OS as a fixed 1x bitmap (see display_server_macos.mm), so on HiDPI screens
## the OS upscales them and they always look blurry. A sprite is re-rendered
## by the GPU every frame from an oversampled raster, so it stays crisp at any
## display scale — at the cost of up to one frame of latency, as noted in the
## Godot custom-cursor docs.

## Which cursor art is currently shown.
enum State {
	POINTER,  ## Default pointing hand.
	GRAB,     ## Dragging an instruction block over a valid drop target.
	GRAB_ERR, ## Dragging over a spot that would reject the drop.
}

## Base on-screen cursor size in viewport units, at size scale 1.0.
const CURSOR_SIZE := 26.0
## The SVGs are rasterised this many times larger than CURSOR_SIZE and the
## sprite scaled back down, so the art survives HiDPI/stretch upscaling and
## the accessibility size setting enlarging it (raster stays 6x the base size).
const OVERSAMPLE := 6.0
## Allowed range of the accessibility size multiplier.
const MIN_SIZE_SCALE := 0.75
const MAX_SIZE_SCALE := 3.0
## Drawn above every other CanvasLayer in the game.
const CURSOR_LAYER := 100

const POINTER_SVG := "res://cursors/mickey-pointer.svg"
const GRAB_SVG := "res://cursors/mickey-grab.svg"
const GRAB_ERR_SVG := "res://cursors/mickey-grab-err.svg"

## The single live instance, so static helpers can drive the cursor from
## anywhere (InstructionBlock's drag paths) without plumbing references around.
static var _instance: SoftwareCursor = null
## Accessibility multiplier on CURSOR_SIZE; static so it survives the cursor
## being toggled off and back on in settings.
static var _size_scale: float = 1.0

var _sprite: Sprite2D = null
var _state: State = State.POINTER
## State -> CursorTexture.Cursor (oversampled, mipmapped), filled in _ready.
var _art: Dictionary = {}

## Swaps the displayed cursor art; safe to call while the cursor is disabled.
static func set_state(state: State) -> void:
	if _instance == null:
		return
	_instance._state = state
	_instance._apply_state()

## Applies the accessibility size setting; safe to call while disabled — the
## value is remembered and picked up by the next instance in _ready.
static func set_size_scale(scale: float) -> void:
	_size_scale = clampf(scale, MIN_SIZE_SCALE, MAX_SIZE_SCALE)
	if _instance != null:
		_instance._apply_size()

func _init() -> void:
	layer = CURSOR_LAYER
	# Keep tracking the mouse even if the game tree gets paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _enter_tree() -> void:
	_instance = self
	# Assume the mouse starts over the window (the common case when the setting
	# is toggled on); a WM_MOUSE_EXIT will correct this if it doesn't.
	_set_mouse_inside(true)

## Restores the OS pointer when the cursor is disabled in settings (or on quit).
func _exit_tree() -> void:
	if _instance == self:
		_instance = null
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _ready() -> void:
	_sprite = $Sprite
	_sprite.centered = false
	# Mipmaps matter here: the oversampled raster is drawn minified most of the
	# time, and plain linear filtering would shimmer/alias on the thin outlines.
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_apply_size()
	_art = {
		State.POINTER: _load_art(POINTER_SVG, CursorTexture.HotspotMode.TIP),
		State.GRAB: _load_art(GRAB_SVG, CursorTexture.HotspotMode.CENTER),
		State.GRAB_ERR: _load_art(GRAB_ERR_SVG, CursorTexture.HotspotMode.CENTER),
	}
	_apply_state()
	_sprite.position = _sprite.get_viewport().get_mouse_position()

## Move on the input event itself (lowest latency) and once per frame as a
## fallback for motion that arrives without an event (e.g. viewport scrolls).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _sprite != null:
		_sprite.position = (event as InputEventMouseMotion).position

func _process(_delta: float) -> void:
	if _sprite != null:
		_sprite.position = _sprite.get_viewport().get_mouse_position()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_EXIT:
			_set_mouse_inside(false)
		NOTIFICATION_WM_MOUSE_ENTER:
			_set_mouse_inside(true)

## Keeps the sprite and the OS pointer mutually exclusive: over the window we
## hide the OS cursor and draw the sprite; once the mouse leaves we must undo
## MOUSE_MODE_HIDDEN, otherwise the OS pointer stays hidden outside the window
## too and nothing is drawn there at all.
func _set_mouse_inside(inside: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if inside else Input.MOUSE_MODE_VISIBLE)
	if _sprite != null:
		_sprite.visible = inside

## Rasterises one cursor SVG oversampled, with mipmaps generated so the sprite
## filters cleanly at any scale. Reuses CursorTexture for raster + hotspot.
func _load_art(svg_path: String, hotspot_mode: CursorTexture.HotspotMode) -> CursorTexture.Cursor:
	var cursor := CursorTexture.load_cursor(svg_path, CURSOR_SIZE * OVERSAMPLE, hotspot_mode)
	if cursor == null:
		return null
	var image := cursor.texture.get_image()
	image.generate_mipmaps()
	return CursorTexture.Cursor.new(ImageTexture.create_from_image(image), cursor.hotspot)

## Resizes the sprite to CURSOR_SIZE * the accessibility multiplier. The
## hotspot offset is in raster pixels, so the sprite scale keeps it anchored.
func _apply_size() -> void:
	if _sprite != null:
		_sprite.scale = Vector2.ONE * (_size_scale / OVERSAMPLE)

## Points the sprite at the current state's art, anchoring it by the hotspot
## (the offset is in raster pixels, so the sprite scale maps it to screen units).
func _apply_state() -> void:
	var cursor: CursorTexture.Cursor = _art.get(_state)
	if cursor == null or _sprite == null:
		return
	_sprite.texture = cursor.texture
	_sprite.offset = -cursor.hotspot
