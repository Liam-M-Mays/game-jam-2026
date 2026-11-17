extends TextureProgressBar
## The food bar. It grows one art pixel taller for every silo (every time the food cap goes up),
## until it would reach the `ceiling` control (the speed button). The rounded ends never stretch,
## and there is a marker line every MARKER_SPACING pixels counted up from the bottom.

const GREEN := Color("4fc24a")
const YELLOW := Color("ffd91a")
const RED := Color("c8242e")
const FILL_SHADER := preload("res://assets/Shaders/hunger_bar.gdshader")
const FONT_SIZE := 24
const TOOLTIP_GAP := 16.0
const TOOLTIP_WIDTH := 440.0
const TITLE_COLOR := "ffe08a"
const GOOD_COLOR := "7be36f"
const OK_COLOR := "ffd91a"
const BAD_COLOR := "ff6b5b"

const ART := preload("res://assets/Art/UI/hunger_bar.png")
const FRAME_REGION := Rect2i(0, 0, 7, 65)
const FILL_REGION := Rect2i(8, 0, 7, 65)
const BASE_LENGTH := 65
const CAP_ROWS := 3
const PLAIN_ROW := 8
const MARKER_ROW := 16
const MARKER_SPACING := 16
## Same scale as the rest of the HUD art.
const SCALE := 4
## Screen pixels kept free between the top of the bar and the ceiling.
const CEILING_GAP := 16.0

@export var tooltip_style: StyleBox
@export var food_plate: Control
@export var food_label: Label
## The bar stops growing before it reaches this control.
@export var ceiling: Control

var _fill_material: ShaderMaterial
var _tooltip: PanelContainer
var _tooltip_label: RichTextLabel
var _label_color: Color
var _length := 0


func _ready() -> void:
	fill_mode = FILL_BOTTOM_TO_TOP
	_fill_material = ShaderMaterial.new()
	_fill_material.shader = FILL_SHADER
	material = _fill_material
	_make_tooltip()
	_refresh()


func _process(_delta: float) -> void:
	_refresh()
	_update_tooltip()


func _refresh() -> void:
	_update_length()
	max_value = Inventory.food_cap()
	value = Inventory.count("food")
	var color := _fill_color()
	_fill_material.set_shader_parameter("fill_color", color)
	_apply_label_color(color)


func _apply_label_color(color: Color) -> void:
	if not food_label or color == _label_color:
		return
	_label_color = color
	food_label.add_theme_color_override("font_color", color)


func _fill_color() -> Color:
	if GameState.hunger > Population.rules.grow_above:
		return GREEN
	if GameState.hunger < Population.rules.starve_below:
		return RED
	return YELLOW


func _update_tooltip() -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != self and hovered != food_plate:
		_tooltip.hide()
		return
	_tooltip_label.text = _tooltip_text()
	_tooltip.show()
	_tooltip.reset_size()
	_tooltip.global_position = Vector2(global_position.x - _tooltip.size.x - TOOLTIP_GAP, _tooltip_top())


func _tooltip_top() -> float:
	var centered := global_position.y + (size.y - _tooltip.size.y) / 2.0
	if not food_plate:
		return centered
	return minf(centered, food_plate.global_position.y - _tooltip.size.y - TOOLTIP_GAP)


func _tooltip_text() -> String:
	var food := Inventory.count("food")
	var meeples := JobSystem.workers.size()
	var lines := ["[color=#%s]Food to meeple ratio[/color]" % TITLE_COLOR]
	if meeples == 0:
		lines.append("%d food, no meeples to feed" % food)
		return "\n".join(lines)
	lines.append("%d food : %d meeples (%.2f each)" % [food, meeples, float(food) / meeples])
	lines.append(_outcome_text(meeples))
	lines.append("With no food, meeples can die while they work. Over %.2f each they reproduce" % _ratio_at(Population.rules.grow_above))
	return "\n".join(lines)


func _outcome_text(meeples: int) -> String:
	if Inventory.count("food") <= 0:
		return "[color=#%s]Working meeples can die[/color]" % BAD_COLOR
	if GameState.hunger < Population.rules.starve_below:
		return "[color=#%s]Running out of food[/color]" % BAD_COLOR
	if GameState.hunger <= Population.rules.grow_above:
		return "[color=#%s]Safe, won't reproduce[/color]" % OK_COLOR
	if meeples >= Population.capacity():
		return "[color=#%s]Safe, build huts to reproduce[/color]" % OK_COLOR
	return "[color=#%s]Meeples will reproduce[/color]" % GOOD_COLOR


func _ratio_at(hunger: float) -> float:
	return hunger / GameState.MAX_HUNGER * Population.rules.food_per_meeple


func _make_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.top_level = true
	if tooltip_style:
		_tooltip.add_theme_stylebox_override("panel", tooltip_style)
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.scroll_active = false
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size.x = TOOLTIP_WIDTH
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_tooltip.add_child(_tooltip_label)
	add_child(_tooltip)
	_tooltip.hide()


func _update_length() -> void:
	var wanted := mini(BASE_LENGTH + get_tree().get_nodes_in_group(Silo.GROUP).size(), _max_length())
	if wanted == _length:
		return
	_length = wanted
	nine_patch_stretch = false
	texture_under = _build(FRAME_REGION, _length)
	texture_progress = _build(FILL_REGION, _length)
	custom_minimum_size = Vector2(FRAME_REGION.size.x, _length) * SCALE


## The longest the bar can be (in art pixels) without reaching the ceiling, at the current HUD size.
func _max_length() -> int:
	if not ceiling or not ceiling.is_visible_in_tree():
		return BASE_LENGTH + 1000
	var bottom := (get_global_transform() * Vector2(0.0, size.y)).y
	var ceiling_bottom := (ceiling.get_global_transform() * Vector2(0.0, ceiling.size.y)).y
	var screen_scale := get_global_transform().get_scale().y
	return maxi(BASE_LENGTH, floori((bottom - ceiling_bottom - CEILING_GAP) / (SCALE * screen_scale)))


## Builds one bar piece at the given length: the art's top and bottom ends, a plain middle,
## and the art's marker line repeated every MARKER_SPACING pixels up from the bottom.
func _build(region: Rect2i, length: int) -> Texture2D:
	var piece := ART.get_image().get_region(region)
	var width := region.size.x
	var image := Image.create_empty(width, length, false, Image.FORMAT_RGBA8)
	image.blit_rect(piece, Rect2i(0, 0, width, CAP_ROWS), Vector2i.ZERO)
	for y in range(CAP_ROWS, length - CAP_ROWS):
		image.blit_rect(piece, Rect2i(0, PLAIN_ROW, width, 1), Vector2i(0, y))
	image.blit_rect(piece, Rect2i(0, BASE_LENGTH - CAP_ROWS, width, CAP_ROWS), Vector2i(0, length - CAP_ROWS))
	var y := length - 1 - MARKER_SPACING
	while y > CAP_ROWS:
		image.blit_rect(piece, Rect2i(0, MARKER_ROW, width, 1), Vector2i(0, y))
		y -= MARKER_SPACING
	image.resize(width * SCALE, length * SCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)
