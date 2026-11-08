class_name BuildMenu
extends Control

const BUILDINGS: Array[PackedScene] = [
	preload("res://assets/Scenes/Buildings/small_hut.tscn"),
	preload("res://assets/Scenes/Buildings/stone_hut.tscn"),
	preload("res://assets/Scenes/Buildings/lumberjack.tscn"),
	preload("res://assets/Scenes/Buildings/farm.tscn"),
	preload("res://assets/Scenes/Buildings/barn.tscn"),
	preload("res://assets/Scenes/Buildings/wood_pile.tscn"),
	preload("res://assets/Scenes/Buildings/stone_pile.tscn"),
]
const BUTTON_SIZE := Vector2(360, 96)
const ICON_SIZE := 96
const FONT_SIZE := 24

@export var building_list: Container
@export var back_button: TextureButton
@export var unavailable_tint := Color(1, 1, 1, 0.5)
@export var locked_tint := Color(0.5, 0.5, 0.5, 0.6)

var build_system: BuildSystem
var _templates := {}
var _upgrade_button: Button
var _upgrade_icon_level := 0


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
		var template: Building = scene.instantiate()
		_templates[scene] = template
		var button := _make_button()
		button.set_meta("scene", scene)
		button.icon = template.icon()
		button.pressed.connect(_on_building_pressed.bind(scene))
		building_list.add_child(button)
	Inventory.changed.connect(_refresh)
	JobSystem.changed.connect(_refresh)
	_refresh()


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
	get_tree().paused = true


func unlocked_names(level: int) -> PackedStringArray:
	var names := PackedStringArray()
	for scene in BUILDINGS:
		if _templates.has(scene) and _templates[scene].required_town_hall_level == level:
			names.append(display_name(scene))
	return names


func close() -> void:
	hide()
	get_tree().paused = false


func _make_button() -> Button:
	var button := Button.new()
	button.expand_icon = true
	button.custom_minimum_size = BUTTON_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	return button


func _refresh_upgrade() -> void:
	var hall := TownHall.find_town_hall()
	if hall == null or hall.is_max_level():
		_upgrade_button.hide()
		return
	_upgrade_button.show()
	var next_level := hall.level() + 1
	if _upgrade_icon_level != next_level:
		_upgrade_button.icon = hall.level_icon(next_level)
		_upgrade_icon_level = next_level
	_upgrade_button.text = "Upgrade Town Hall to lv %d   %d meeples" % [next_level, hall.meeples_for_next_level()]
	_upgrade_button.modulate = Color.WHITE if hall.can_upgrade() else unavailable_tint


func _on_upgrade_pressed() -> void:
	var hall := TownHall.find_town_hall()
	if hall == null:
		return
	if not hall.can_upgrade():
		GameState.warn("You need %d meeples to upgrade your Town Hall (you have %d)" % [hall.meeples_for_next_level(), JobSystem.workers.size()])
		return
	hall.upgrade()
	_refresh()


func _refresh() -> void:
	if _upgrade_button:
		_refresh_upgrade()
	for button in building_list.get_children():
		if not button.has_meta("scene"):
			continue
		var scene: PackedScene = button.get_meta("scene")
		if not _templates.has(scene):
			continue
		var building: Building = _templates[scene]
		if _is_locked(building):
			button.text = "%s   Town Hall lv %d" % [display_name(scene), building.required_town_hall_level]
			button.modulate = locked_tint
			continue
		button.text = "%s   %s" % [display_name(scene), _cost_text(building.min_to_start)]
		button.modulate = Color.WHITE if building.can_start() else unavailable_tint


func _on_building_pressed(scene: PackedScene) -> void:
	var building: Building = _templates[scene]
	if _is_locked(building):
		GameState.warn("You need Town Hall level %d to build %s" % [building.required_town_hall_level, display_name(scene)])
		return
	if not building.can_afford():
		GameState.warn("You need more materials to build %s" % display_name(scene))
		return
	if not building.can_start():
		GameState.warn("Job queue is full")
		return
	if not build_system:
		push_warning("BuildMenu has no BuildSystem assigned")
		return
	close()
	build_system.start_build(scene)


func _is_locked(building: Building) -> bool:
	return building.required_town_hall_level > TownHall.current_level()


func _cost_text(costs: Dictionary) -> String:
	if costs.is_empty():
		return "Free"
	var parts := []
	for kind in costs:
		parts.append("%d %s" % [costs[kind], kind])
	return " / ".join(parts)
