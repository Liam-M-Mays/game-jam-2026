extends TextureProgressBar

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

@export var tooltip_style: StyleBox
@export var food_plate: Control
@export var food_label: Label

var _fill_material: ShaderMaterial
var _tooltip: PanelContainer
var _tooltip_label: RichTextLabel
var _label_color: Color


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
	if GameState.hunger > Population.RULES.grow_above:
		return GREEN
	if GameState.hunger < Population.RULES.starve_below:
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
	lines.append("Under %.2f each meeples die, over %.2f each they reproduce" % [_ratio_at(Population.RULES.starve_below), _ratio_at(Population.RULES.grow_above)])
	return "\n".join(lines)


func _outcome_text(meeples: int) -> String:
	if GameState.hunger < Population.RULES.starve_below:
		return "[color=#%s]Meeples will die[/color]" % BAD_COLOR
	if GameState.hunger <= Population.RULES.grow_above:
		return "[color=#%s]Safe, won't reproduce[/color]" % OK_COLOR
	if meeples >= Population.capacity():
		return "[color=#%s]Safe, build huts to reproduce[/color]" % OK_COLOR
	return "[color=#%s]Meeples will reproduce[/color]" % GOOD_COLOR


func _ratio_at(hunger: float) -> float:
	return hunger / GameState.MAX_HUNGER * Population.RULES.food_per_meeple


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
