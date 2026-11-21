class_name UiArt
extends RefCounted
## Brady's button and menu art (source: ART/New_Menu_Buttons.png), sliced into
## assets/Art/UI/settings_ui.png. Every button sits in its own row as normal, hover, pressed.
## The three states share one canvas size, lined up so the button doesn't jump between states:
## hover adds the white ring and pressed sinks to the bottom.

const SHEET := preload("res://assets/Art/UI/settings_ui.png")
## Same scale as the other menu buttons in the game.
const SCALE := 4

const BUTTONS := {
	"controls": [Rect2(2, 2, 74, 23), Rect2(78, 2, 74, 23), Rect2(154, 2, 74, 23)],
	"settings": [Rect2(2, 27, 71, 23), Rect2(75, 27, 71, 23), Rect2(148, 27, 71, 23)],
	"quit": [Rect2(2, 52, 42, 23), Rect2(46, 52, 42, 23), Rect2(90, 52, 42, 23)],
	"back": [Rect2(2, 77, 40, 23), Rect2(44, 77, 40, 23), Rect2(86, 77, 40, 23)],
	"start": [Rect2(2, 102, 47, 23), Rect2(51, 102, 47, 23), Rect2(100, 102, 47, 23)],
	"resume": [Rect2(2, 127, 56, 23), Rect2(60, 127, 56, 23), Rect2(118, 127, 56, 23)],
	"credits": [Rect2(2, 152, 62, 23), Rect2(66, 152, 62, 23), Rect2(130, 152, 62, 23)],
	"display": [Rect2(2, 177, 62, 23), Rect2(66, 177, 62, 23), Rect2(130, 177, 62, 23)],
	"gameplay": [Rect2(2, 202, 71, 23), Rect2(75, 202, 71, 23), Rect2(148, 202, 71, 23)],
	"audio": [Rect2(2, 227, 50, 23), Rect2(54, 227, 50, 23), Rect2(106, 227, 50, 23)],
	"other": [Rect2(2, 252, 48, 23), Rect2(52, 252, 48, 23), Rect2(102, 252, 48, 23)],
	"retry": [Rect2(2, 277, 47, 23), Rect2(51, 277, 47, 23), Rect2(100, 277, 47, 23)],
	"build": [Rect2(2, 302, 47, 23), Rect2(51, 302, 47, 23), Rect2(100, 302, 47, 23)],
	"menu": [Rect2(2, 327, 43, 23), Rect2(47, 327, 43, 23), Rect2(92, 327, 43, 23)],
	"start_gray": [Rect2(2, 352, 45, 21), Rect2(49, 352, 45, 21), Rect2(96, 352, 45, 21)],
	"quit_gray": [Rect2(2, 375, 40, 21), Rect2(44, 375, 40, 21), Rect2(86, 375, 40, 21)],
	"credits_gray": [Rect2(2, 398, 60, 21), Rect2(64, 398, 60, 21), Rect2(126, 398, 60, 21)],
	"continue_gray": [Rect2(2, 563, 70, 21), Rect2(74, 563, 70, 21), Rect2(146, 563, 70, 21)],
	"settings_gray": [Rect2(2, 421, 69, 21), Rect2(73, 421, 69, 21), Rect2(144, 421, 69, 21)],
}

const FRAMES := {
	"tab": Rect2(2, 444, 73, 29),
	"tab_active": Rect2(77, 444, 73, 29),
	"panel": Rect2(2, 475, 287, 86),
}

static var _scaled_cache := {}


## Puts the art on a TextureButton and sizes it to SCALE times the art.
static func apply(button: TextureButton, name: String) -> void:
	var rects: Array = BUTTONS[name]
	button.texture_normal = _atlas(rects[0])
	button.texture_hover = _atlas(rects[1])
	button.texture_focused = _atlas(rects[1])
	button.texture_pressed = _atlas(rects[2])
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = size_of(name)


static func button(name: String) -> TextureButton:
	var made := TextureButton.new()
	apply(made, name)
	return made


static func size_of(name: String) -> Vector2:
	return (BUTTONS[name][0] as Rect2).size * SCALE


## A 9-slice StyleBox from one of the frame pieces (tab, tab_active, panel), blown up to SCALE.
## margins are the art pixels that must not stretch; padding is the empty space inside, also in art pixels.
static func frame(name: String, margins: Vector4, padding: Vector4) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _scaled(FRAMES[name])
	style.texture_margin_left = margins.x * SCALE
	style.texture_margin_top = margins.y * SCALE
	style.texture_margin_right = margins.z * SCALE
	style.texture_margin_bottom = margins.w * SCALE
	style.content_margin_left = padding.x * SCALE
	style.content_margin_top = padding.y * SCALE
	style.content_margin_right = padding.z * SCALE
	style.content_margin_bottom = padding.w * SCALE
	return style


static func _atlas(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = region
	return atlas


## StyleBoxTexture draws its edges at texture size, so frames get a copy scaled up without blurring.
static func _scaled(region: Rect2) -> Texture2D:
	if _scaled_cache.has(region):
		return _scaled_cache[region]
	var image := SHEET.get_image().get_region(Rect2i(region))
	image.resize(image.get_width() * SCALE, image.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(image)
	_scaled_cache[region] = texture
	return texture
