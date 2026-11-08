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
@export var button_size := Vector2(200, 220)
@export var unavailable_tint := Color(1, 1, 1, 0.5)

var build_system: BuildSystem
var _templates := {}


static func display_name(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename().trim_suffix("_build").capitalize()


static func building_scenes() -> Array[PackedScene]:
	var keys := BuildSystem.HOTKEYS.keys()
	keys.sort()
	var scenes: Array[PackedScene] = []
	for key in keys:
		scenes.append(BuildSystem.HOTKEYS[key])
	return scenes


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	if back_button:
		back_button.pressed.connect(close)
	for scene in BUILDINGS:
		var template: Building = scene.instantiate()
		_templates[scene] = template
		var button := Button.new()
		button.set_meta("scene", scene)
		button.icon = template.icon()
		button.expand_icon = true
		button.custom_minimum_size = BUTTON_SIZE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", ICON_SIZE)
		button.add_theme_font_size_override("font_size", FONT_SIZE)
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


func close() -> void:
	hide()
	get_tree().paused = false


func _make_button(scene: PackedScene, template: Building) -> Button:
	var button := Button.new()
	button.set_meta("scene", scene)
	button.custom_minimum_size = button_size
	button.icon = _finished_look(template)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(_on_building_pressed.bind(scene))
	return button


func _finished_look(building: Building) -> Texture2D:
	var texture := building.texture
	if texture == null:
		return null
	var sheet := building.region_rect if building.region_enabled else Rect2(Vector2.ZERO, texture.get_size())
	var cell := sheet.size / Vector2(building.hframes, building.vframes)
	var index := 0 if building.reverse_frames else building.last_stage()
	var column := index % building.hframes
	var row := index / building.hframes
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(sheet.position + cell * Vector2(column, row), cell)
	return atlas


func _refresh() -> void:
	for button in building_list.get_children():
		var scene: PackedScene = button.get_meta("scene")
		if not _templates.has(scene):
			continue
		var building: Building = _templates[scene]
		button.text = "%s   %s" % [display_name(scene), _cost_text(building.min_to_start)]
		button.modulate = Color.WHITE if building.can_start() else unavailable_tint


func _on_building_pressed(scene: PackedScene) -> void:
	var building: Building = _templates[scene]
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


func _cost_text(costs: Dictionary) -> String:
	if costs.is_empty():
		return "Free"
	var parts := []
	for kind in costs:
		parts.append("%d %s" % [costs[kind], kind])
	return " / ".join(parts)
