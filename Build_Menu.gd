class_name BuildMenu
extends Control

const BUILDINGS: Array[PackedScene] = [
	preload("res://assets/Scenes/Buildings/small_hut.tscn"),
	preload("res://assets/Scenes/Buildings/wood_pile.tscn"),
	preload("res://assets/Scenes/Buildings/stone_pile.tscn"),
	preload("res://assets/Scenes/Buildings/lumberjack.tscn"),
	preload("res://assets/Scenes/Buildings/miner.tscn"),
	preload("res://assets/Scenes/Buildings/barn.tscn"),
	preload("res://assets/Scenes/Buildings/farm.tscn"),
	preload("res://assets/Scenes/Buildings/stone_hut.tscn"),
	preload("res://assets/Scenes/Buildings/silo.tscn"),
	preload("res://assets/Scenes/Buildings/windmill.tscn"),
	preload("res://assets/Scenes/Buildings/statue.tscn"),
]
const HOTKEYS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "minus"]
const BUTTON_SIZE := Vector2(440, 80)
const ICON_SIZE := 80
const FONT_SIZE := 24
const ICON_TEXT_GAP := 20
const LOCKED_FONT_COLORS: Array[StringName] = [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]
const LOCKED_ICON_COLORS: Array[StringName] = [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_focus_color"]
const TOOLTIP_OFFSET := Vector2(24, 24)
const TOOLTIP_WIDTH := 440.0
const TOOLTIP_TITLE_COLOR := "ffe08a"
const TOOLTIP_LOCKED_COLOR := "ff6b5b"

@export var building_list: Container
@export var back_button: TextureButton
@export var unavailable_tint := Color(1, 1, 1, 0.5)
@export var locked_tint := Color(0.5, 0.5, 0.5, 0.6)
@export var tooltip_style: StyleBox

var build_system: BuildSystem
var _templates := {}
var _ordered_buildings: Array[PackedScene] = []
var _upgrade_button: Button
var _upgrade_icon_level := 0
var _tooltip: PanelContainer
var _tooltip_label: RichTextLabel


static func display_name(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename().trim_suffix("_build").capitalize()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	if back_button:
		back_button.pressed.connect(close)
	_upgrade_button = _make_button()
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	building_list.add_child(_upgrade_button)
	for scene in BUILDINGS:
		_templates[scene] = scene.instantiate()
	_ordered_buildings = _sorted_buildings()
	for scene in _ordered_buildings:
		var button := _make_button()
		button.set_meta("scene", scene)
		button.icon = _templates[scene].icon()
		button.pressed.connect(_on_building_pressed.bind(scene))
		building_list.add_child(button)
	_make_tooltip()
	Inventory.changed.connect(_refresh)
	JobSystem.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	var button := get_viewport().gui_get_hovered_control() as Button
	if button == null or button.get_parent() != building_list:
		_tooltip.hide()
		return
	_tooltip_label.text = _tooltip_text(button)
	_tooltip.show()
	_tooltip.reset_size()
	var pos := get_local_mouse_position() + TOOLTIP_OFFSET
	_tooltip.position = pos.clamp(Vector2.ZERO, (size - _tooltip.size).max(Vector2.ZERO))


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	for index in mini(HOTKEYS.size(), _ordered_buildings.size()):
		if event.is_action_pressed(HOTKEYS[index]):
			_on_building_pressed(_ordered_buildings[index])
			return


func _exit_tree() -> void:
	if Inventory.changed.is_connected(_refresh):
		Inventory.changed.disconnect(_refresh)
	if JobSystem.changed.is_connected(_refresh):
		JobSystem.changed.disconnect(_refresh)
	for template in _templates.values():
		template.free()
	_templates.clear()


func open() -> void:
	_refresh()
	show()


func unlocked_names(level: int) -> PackedStringArray:
	var names := PackedStringArray()
	for scene in BUILDINGS:
		if _templates.has(scene) and _templates[scene].required_town_hall_level == level:
			names.append(display_name(scene))
	return names


func close() -> void:
	hide()


func _sorted_buildings() -> Array[PackedScene]:
	var sorted: Array[PackedScene] = BUILDINGS.duplicate()
	sorted.sort_custom(_comes_before)
	return sorted


func _comes_before(a: PackedScene, b: PackedScene) -> bool:
	var level_a: int = _templates[a].required_town_hall_level
	var level_b: int = _templates[b].required_town_hall_level
	if level_a != level_b:
		return level_a < level_b
	return BUILDINGS.find(a) < BUILDINGS.find(b)


func _hotkey_label(scene: PackedScene) -> String:
	var index := _ordered_buildings.find(scene)
	if index < 0 or index >= HOTKEYS.size():
		return ""
	return "-" if HOTKEYS[index] == "minus" else HOTKEYS[index]


func _make_button() -> Button:
	var button := Button.new()
	button.expand_icon = true
	button.custom_minimum_size = BUTTON_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	button.add_theme_constant_override("h_separation", ICON_TEXT_GAP)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	return button


func _make_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _tooltip_text(button: Button) -> String:
	if button == _upgrade_button:
		return _upgrade_tooltip_text()
	var scene: PackedScene = button.get_meta("scene")
	var building: Building = _templates[scene]
	var building_name := display_name(scene)
	var lines := [_tooltip_title(building_name), building.description, "Total cost: %s" % _cost_text(building.costs)]
	var hotkey := _hotkey_label(scene)
	if not hotkey.is_empty():
		lines.append("Hotkey: %s" % hotkey)
	if _is_locked(building):
		lines.append("[color=#%s]Needs Town Hall level %d[/color]" % [TOOLTIP_LOCKED_COLOR, building.required_town_hall_level])
	return "\n".join(lines)


func _upgrade_tooltip_text() -> String:
	var hall := TownHall.find_town_hall()
	if hall != null and hall.is_max_level():
		return "\n".join([_tooltip_title("Town Hall"), "Fully upgraded."])
	var next_level := TownHall.current_level() + 1
	var lines := [_tooltip_title("Upgrade Town Hall"), "Raises your Town Hall to level %d." % next_level]
	var names := unlocked_names(next_level)
	if not names.is_empty():
		lines.append("Unlocks: %s" % ", ".join(names))
	return "\n".join(lines)


func _tooltip_title(title: String) -> String:
	return "[color=#%s]%s[/color]" % [TOOLTIP_TITLE_COLOR, title]


func _refresh_upgrade() -> void:
	var hall := TownHall.find_town_hall()
	if hall == null:
		_upgrade_button.hide()
		return
	_upgrade_button.show()
	var next_level := mini(hall.level() + 1, hall.max_level())
	if _upgrade_icon_level != next_level:
		_upgrade_button.icon = hall.level_icon(next_level)
		_upgrade_icon_level = next_level
	if hall.is_max_level():
		_upgrade_button.text = "Fully upgraded"
		_upgrade_button.modulate = Color.WHITE
		return
	_upgrade_button.text = "Upgrade lv %d   %d meeples" % [next_level, hall.meeples_for_next_level()]
	_upgrade_button.modulate = Color.WHITE if hall.can_upgrade() else unavailable_tint


func _on_upgrade_pressed() -> void:
	var hall := TownHall.find_town_hall()
	if hall == null or hall.is_max_level():
		return
	if not hall.can_upgrade():
		GameState.warn("You need %d meeples to upgrade your Town Hall (you have %d)" % [hall.meeples_for_next_level(), JobSystem.workers.size()])
		return
	hall.upgrade()
	_refresh()


func _refresh() -> void:
	if _upgrade_button:
		_refresh_upgrade()
	var counts := _built_counts()
	for button in building_list.get_children():
		if not button.has_meta("scene"):
			continue
		var scene: PackedScene = button.get_meta("scene")
		if not _templates.has(scene):
			continue
		var building: Building = _templates[scene]
		if _is_locked(building):
			button.text = "%s   Hall lv %d" % [_button_name(scene, counts), building.required_town_hall_level]
			button.modulate = Color.WHITE
			for color_name in LOCKED_FONT_COLORS:
				button.add_theme_color_override(color_name, locked_tint)
			for color_name in LOCKED_ICON_COLORS:
				button.add_theme_color_override(color_name, Color.BLACK)
			continue
		for color_name in LOCKED_FONT_COLORS + LOCKED_ICON_COLORS:
			button.remove_theme_color_override(color_name)
		button.text = "%s   %s" % [_button_name(scene, counts), _cost_text(building.min_to_start)]
		button.modulate = Color.WHITE if building.can_afford() else unavailable_tint


func _on_building_pressed(scene: PackedScene) -> void:
	var building: Building = _templates[scene]
	if _is_locked(building):
		GameState.warn("You need Town Hall level %d to build %s" % [building.required_town_hall_level, display_name(scene)])
		return
	if not building.can_afford():
		GameState.warn("You need more materials to build %s" % display_name(scene))
		return
	if not build_system:
		push_warning("BuildMenu has no BuildSystem assigned")
		return
	close()
	build_system.start_build(scene)


func _button_name(scene: PackedScene, counts: Dictionary) -> String:
	return "[%d] %s" % [counts.get(scene.resource_path, 0), display_name(scene)]


func _built_counts() -> Dictionary:
	var counts := {}
	for node in get_tree().get_nodes_in_group(Building.COMPLETED_GROUP):
		counts[node.scene_file_path] = counts.get(node.scene_file_path, 0) + 1
	return counts


func _is_locked(building: Building) -> bool:
	return building.required_town_hall_level > TownHall.current_level()


func _cost_text(costs: Dictionary) -> String:
	if costs.is_empty():
		return "Free"
	var parts := []
	for kind in costs:
		parts.append("%d %s" % [costs[kind], kind])
	return " / ".join(parts)
