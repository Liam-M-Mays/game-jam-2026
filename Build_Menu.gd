class_name BuildMenu
extends Control

const BUILDINGS: Array[PackedScene] = [
	preload("res://assets/Scenes/Buildings/hut_build.tscn"),
]

@export var building_list: Container
@export var back_button: TextureButton
@export var unavailable_tint := Color(1, 1, 1, 0.5)

var build_system: BuildSystem
var _templates := {}


static func display_name(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename().trim_suffix("_build").capitalize()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	if back_button:
		back_button.pressed.connect(close)
	for scene in BUILDINGS:
		_templates[scene] = scene.instantiate()
		var button := Button.new()
		button.set_meta("scene", scene)
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


func _refresh() -> void:
	for button in building_list.get_children():
		var scene: PackedScene = button.get_meta("scene")
		if not _templates.has(scene):
			continue
		var building: Building = _templates[scene]
		button.text = "%s   %s" % [display_name(scene), _cost_text(building.costs)]
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
	var parts := []
	for kind in costs:
		parts.append("%d %s" % [costs[kind], kind])
	return " / ".join(parts)
