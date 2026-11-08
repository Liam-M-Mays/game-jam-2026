class_name BuildMenu
extends Control

const BUILDINGS: Array[PackedScene] = [
	preload("res://assets/Scenes/Buildings/hut_build.tscn"),
]

@export var building_list: Container
@export var back_button: TextureButton

var build_system: BuildSystem
var _templates := {}


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
		var building: Building = _templates[scene]
		button.text = "%s   %s" % [_display_name(scene), _cost_text(building.costs)]
		button.disabled = not building.can_start()


func _on_building_pressed(scene: PackedScene) -> void:
	if not build_system:
		push_warning("BuildMenu has no BuildSystem assigned")
		return
	close()
	build_system.start_build(scene)


func _display_name(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename().trim_suffix("_build").capitalize()


func _cost_text(costs: Dictionary) -> String:
	var parts := []
	for kind in costs:
		parts.append("%d %s" % [costs[kind], kind])
	return " / ".join(parts)
