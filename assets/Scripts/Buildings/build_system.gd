extends Node2D

const BUILDINGS := {
	"2": preload("res://assets/Scenes/hut_build.tscn"),
}
const PREVIEW_VALID := Color(0.3, 1, 0.3, 0.6)
const PREVIEW_BLOCKED := Color(1, 0.3, 0.3, 0.6)

@export var grid : Grid
@export var cursor : CellCursor

var _scene : PackedScene = null
var _preview : Building = null

func _input(event : InputEvent) -> void:
	for action in BUILDINGS:
		if event.is_action_pressed(action):
			_select(BUILDINGS[action])
			return
	if event.is_action_pressed("ui_cancel"):
		_select(null)
	elif _preview != null and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_place()
		get_viewport().set_input_as_handled()

func _process(_delta : float) -> void:
	if _preview == null:
		return
	var mouse := get_global_mouse_position()
	var anchor := grid.cell_at(mouse)
	_preview.visible = anchor != null
	if anchor != null:
		_preview.position = anchor.position
	_preview.modulate = PREVIEW_VALID if _can_place(grid.free_cells_at(mouse, _preview.footprint)) else PREVIEW_BLOCKED

func _select(scene : PackedScene) -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null
	_scene = scene
	cursor.enabled = scene != null
	if scene == null:
		return
	_preview = scene.instantiate()
	_preview.show_as_preview()
	grid.add_child(_preview)

func _can_place(cells : Array[Cell]) -> bool:
	return not cells.is_empty() and _preview.can_start()

func _try_place() -> void:
	var cells := grid.free_cells_at(get_global_mouse_position(), _preview.footprint)
	if not _can_place(cells):
		_preview.reject()
		return
	var site : Building = _scene.instantiate()
	grid.place(site, cells)
	site.start_build()
