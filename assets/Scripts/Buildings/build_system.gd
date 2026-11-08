extends Node2D
class_name BuildSystem

signal build_started(scene : PackedScene)
signal build_ended
signal building_placed(building : Building)
signal building_completed(building : Building)
signal placement_failed(reason : PlacementError)

enum PlacementError { NONE, BLOCKED, CANT_AFFORD, QUEUE_FULL }

const HOTKEYS := {
	"2": preload("res://assets/Scenes/Buildings/small_hut.tscn"),
	"3": preload("res://assets/Scenes/Buildings/stone_hut.tscn"),
	"4": preload("res://assets/Scenes/Buildings/barn.tscn"),
	"5": preload("res://assets/Scenes/Buildings/farm.tscn"),
	"6": preload("res://assets/Scenes/Buildings/stone_pile.tscn"),
	"7": preload("res://assets/Scenes/Buildings/wood_pile.tscn"),
	"8": preload("res://assets/Scenes/Buildings/lumberjack.tscn"),
}

@export var grid : Grid
@export var cursor : CellCursor

var _scene : PackedScene = null
var _preview : Building = null

func start_build(scene : PackedScene) -> void:
	_clear_preview()
	_scene = scene
	cursor.enabled = true
	_preview = scene.instantiate()
	grid.add_child(_preview)
	_preview.show_as_preview()
	build_started.emit(scene)

func end_build() -> void:
	if not is_building():
		return
	_clear_preview()
	_scene = null
	cursor.enabled = false
	build_ended.emit()

func is_building() -> bool:
	return _preview != null

func _input(event : InputEvent) -> void:
	for action in HOTKEYS:
		if event.is_action_pressed(action):
			start_build(HOTKEYS[action])
			return
	if not is_building():
		return
	if event.is_action_pressed("ui_cancel"):
		end_build()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_place()
		get_viewport().set_input_as_handled()

func _process(_delta : float) -> void:
	if not is_building():
		return
	var mouse := get_global_mouse_position()
	var anchor := grid.cell_at(mouse)
	_preview.visible = anchor != null
	if anchor != null:
		_preview.position = anchor.position
	var valid := _placement_error(grid.free_cells_at(mouse, _preview.footprint)) == PlacementError.NONE
	_preview.set_preview_blocked(not valid)

func _placement_error(cells : Array[Cell]) -> PlacementError:
	if cells.is_empty():
		return PlacementError.BLOCKED
	if not _preview.can_afford():
		return PlacementError.CANT_AFFORD
	if not JobSystem.has_room(_preview.jobs_needed()):
		return PlacementError.QUEUE_FULL
	return PlacementError.NONE

func _try_place() -> void:
	var cells := grid.free_cells_at(get_global_mouse_position(), _preview.footprint)
	var error := _placement_error(cells)
	if error != PlacementError.NONE:
		_preview.reject()
		placement_failed.emit(error)
		return
	var site : Building = _scene.instantiate()
	grid.place(site, cells)
	site.completed.connect(func(): building_completed.emit(site))
	site.start_construction()
	building_placed.emit(site)
	end_build()

func _clear_preview() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null
