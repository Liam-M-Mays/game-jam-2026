extends TextureProgressBar

const GREEN_ABOVE := 0.5
const RED_BELOW := 0.25
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

var _fill_material: ShaderMaterial
var _tooltip: PanelContainer
var _tooltip_label: RichTextLabel


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
	_fill_material.set_shader_parameter("fill_color", _fill_color(ratio))


func _fill_color(fill: float) -> Color:
	if fill > GREEN_ABOVE:
		return GREEN
	if fill < RED_BELOW:
		return RED
	return YELLOW


func _update_tooltip() -> void:
	if get_viewport().gui_get_hovered_control() != self:
		_tooltip.hide()
		return
	_tooltip_label.text = _tooltip_text()
	_tooltip.show()
	_tooltip.reset_size()
	_tooltip.global_position = global_position + Vector2(-_tooltip.size.x - TOOLTIP_GAP, (size.y - _tooltip.size.y) / 2.0)


func _tooltip_text() -> String:
	var food := Inventory.count("food")
	var meeples := JobSystem.workers.size()
	var lines := ["[color=#%s]Food to meeple ratio[/color]" % TITLE_COLOR]
	if meeples == 0:
		lines.append("%d food, no meeples to feed" % food)
		return "\n".join(lines)
	lines.append("%d food : %d meeples (%.2f each)" % [food, meeples, float(food) / meeples])
	lines.append(_outcome_text(meeples))
	lines.append("Under %.2f each meeples die, over %.2f each they reproduce" % [_ratio_at(Population.STARVE_BELOW), _ratio_at(Population.GROW_ABOVE)])
	return "\n".join(lines)


func _outcome_text(meeples: int) -> String:
	if GameState.hunger < Population.STARVE_BELOW:
		return "[color=#%s]Meeples will die[/color]" % BAD_COLOR
	if GameState.hunger <= Population.GROW_ABOVE:
		return "[color=#%s]Meeples are safe, but won't reproduce[/color]" % OK_COLOR
	if meeples >= Population.capacity():
		return "[color=#%s]Meeples are safe, build more huts so they can reproduce[/color]" % OK_COLOR
	return "[color=#%s]Meeples will reproduce[/color]" % GOOD_COLOR


func _ratio_at(hunger: float) -> float:
	return hunger / GameState.MAX_HUNGER * GameState.FULL_FOOD_PER_MEEPLE


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
