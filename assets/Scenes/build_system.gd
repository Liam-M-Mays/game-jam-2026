extends Node2D

const BUILDINGS := {
	"1": preload("res://assets/Scenes/hut.tscn"),
}

const PREVIEW_VALID := Color(0.3, 1, 0.3, 0.6)
const PREVIEW_BLOCKED := Color(1, 0.3, 0.3, 0.6)

@onready var grid = $"../Grid"
@onready var mouse_area = $"../Mouse"

var current : PackedScene = null
var _preview : building = null

func _input(event: InputEvent) -> void:
	for action in BUILDINGS:
		if event.is_action_pressed(action):
			_select(BUILDINGS[action])
			return
	if event.is_action_pressed("ui_cancel"):
		current = null
		mouse_area.enabled = false
		_clear_preview()
	elif current != null and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_place_current()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if current == null:
		return
	var mouse := get_global_mouse_position()
	var anchor = grid.cell_at(mouse)
	_preview.visible = anchor != null
	if anchor != null:
		_preview.position = anchor.position
	var valid : bool = not grid.free_cells_at(mouse, _preview.width).is_empty()
	_preview.modulate = PREVIEW_VALID if valid else PREVIEW_BLOCKED

func _select(scene : PackedScene) -> void:
	current = scene
	mouse_area.enabled = true
	_clear_preview()
	_preview = scene.instantiate()
	grid.add_child(_preview)

func _clear_preview() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null

func _place_current() -> void:
	var cells : Array = grid.free_cells_at(get_global_mouse_position(), _preview.width)
	if cells.is_empty():
		return
	var site : building = current.instantiate()
	site.position = cells[0].position
	for cell in cells:
		cell.resource = site
		site.cells.append(cell)
	grid.add_child(site)
	JobSystem.add_build_job(site)
