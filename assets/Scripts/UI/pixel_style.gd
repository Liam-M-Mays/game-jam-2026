class_name PixelStyle
extends RefCounted
## Draws the pixel-art pieces that don't have hand-made art yet (sliders, toggles, arrows,
## VIEW and RESET buttons) in the same colors as the art in UiArt.
## Every box is drawn at art scale and blown up by PX with nearest filtering.

## One art pixel on screen. The other menus use a scale of 4 too.
const PX := 4
const FONT_SIZE := 32

const PANEL := Color("26262b")
const TAB := Color("131313")
const OUTLINE := Color("000000")
const BUTTON := Color("af6546")
const BUTTON_LIP := Color("85452a")
const BUTTON_DIM := Color("8e4e3a")
const BUTTON_DIM_LIP := Color("6a3727")
const DANGER := Color("8a3030")
const DANGER_LIP := Color("5c1f1f")
const HALO := Color.WHITE
const TEXT := Color("ededed")
const TEXT_MUTED := Color("8a8a93")
const TEXT_DIM := Color("e8d5ce")
const TEXT_PRESSED := Color("5e2a1e")
const ACCENT := Color("d9805f")
const DIVIDER := Color("303037")
const DIM := Color(0, 0, 0, 0.5)

static var _cache := {}


## A box with outline rings (outermost first), a fill, and an optional darker lip along the bottom.
## With open_bottom the bottom edge has no outline, for the tab that joins the panel.
static func box(fill: Color, rings: Array[Color], lip := Color.TRANSPARENT, lip_rows := 0, open_bottom := false) -> Texture2D:
	var key := "%s|%s|%s|%d|%s" % [fill, rings, lip, lip_rows, open_bottom]
	if _cache.has(key):
		return _cache[key]
	var ring_count := rings.size()
	var margin := ring_count + 2
	var size := margin * 2 + 2
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			image.set_pixel(x, y, _pixel(x, y, size, fill, rings, lip, lip_rows, open_bottom))
	image.resize(size * PX, size * PX, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func _pixel(x: int, y: int, size: int, fill: Color, rings: Array[Color], lip: Color, lip_rows: int, open_bottom: bool) -> Color:
	var last := size - 1
	var ring := mini(mini(x, y), last - x)
	if not open_bottom:
		ring = mini(ring, last - y)
	var on_x_edge := x == ring or x == last - ring
	var on_y_edge := y == ring or (not open_bottom and y == last - ring)
	# Knock the corner pixel of each ring out to the ring outside it, which rounds the corners.
	if on_x_edge and on_y_edge and ring <= rings.size():
		ring -= 1
	if ring < 0:
		return Color.TRANSPARENT
	if ring < rings.size():
		return rings[ring]
	if lip_rows > 0 and y >= last - rings.size() - lip_rows + 1:
		return lip
	return fill


## A StyleBox that stretches a box texture without blurring its pixels.
static func stylebox(texture: Texture2D, rings: int, pad := Vector4(3, 1, 3, 1)) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	var margin := float((rings + 2) * PX)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = (rings + pad.x) * PX
	style.content_margin_top = (rings + pad.y) * PX
	style.content_margin_right = (rings + pad.z) * PX
	style.content_margin_bottom = (rings + pad.w) * PX
	return style


## Just the white halo, drawn over a control that has keyboard or controller focus.
static func focus_ring() -> StyleBoxTexture:
	return stylebox(box(Color.TRANSPARENT, [HALO, Color.TRANSPARENT]), 2)


## Styles a Button like the pixel buttons: outline, lip, white halo on hover, pressed sinks in.
static func style_button(button: Button, fill := BUTTON, lip := BUTTON_LIP, text := Color.WHITE) -> void:
	var none := Color.TRANSPARENT
	var normal := stylebox(box(fill, [none, OUTLINE], lip, 1), 2)
	var hover := stylebox(box(fill, [HALO, OUTLINE], lip, 1), 2)
	var pressed := stylebox(box(fill, [none, OUTLINE]), 2, Vector4(3, 2, 3, 0))
	var pressed_hover := stylebox(box(fill, [HALO, OUTLINE]), 2, Vector4(3, 2, 3, 0))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed_hover)
	button.add_theme_stylebox_override("focus", focus_ring())
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text)
	button.add_theme_color_override("font_focus_color", text)
	button.add_theme_color_override("font_pressed_color", TEXT_PRESSED)
	button.add_theme_color_override("font_hover_pressed_color", TEXT_PRESSED)
	button.add_theme_constant_override("outline_size", 0)
