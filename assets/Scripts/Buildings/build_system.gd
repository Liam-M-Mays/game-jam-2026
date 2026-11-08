extends Node2D
class_name BuildSystem

signal build_started(scene : PackedScene)
signal build_ended
signal building_placed(building : Building)
signal building_completed(building : Building)
signal placement_failed(reason : PlacementError)

enum PlacementError { NONE, BLOCKED, CANT_AFFORD, QUEUE_FULL, OUT_OF_AREA }

const AREA_COLOR := Color(1.0, 0.95, 0.6)
const AREA_ALPHA := 0.7
const AREA_HOVER_COLOR := Color(1.0, 1.0, 1.0)
const AREA_HOVER_ALPHA := 1.0

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
var _area : Array[Cell] = []

func _ready() -> void:
	add_child(ConstructionTooltip.new())

func start_build(scene : PackedScene) -> void:
	_clear_preview()
	_scene = scene
	_preview = scene.instantiate()
	grid.add_child(_preview)
	_preview.show_as_preview()
	cursor.enabled = not _preview.restricts_placement()
	if _preview.restricts_placement() and _preview.placement_area(grid).is_empty():
		print(_preview.placement_hint())
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
	var cells := grid.free_cells_at(mouse, _preview.footprint)
	if _preview.restricts_placement():
		var area := _preview.placement_area(grid)
		var on_area := not cells.is_empty() and cells.all(func(c): return area.has(c))
		var hovered : Array[Cell] = []
		if on_area:
			hovered = cells
		_show_area(area, hovered)
		_preview.visible = on_area
		if not on_area:
			return
	else:
		_preview.visible = anchor != null
	if anchor != null:
		_preview.position = anchor.position
	_preview.set_preview_blocked(_placement_error(cells) != PlacementError.NONE)

func _show_area(cells : Array[Cell], hovered : Array[Cell] = []) -> void:
	for cell in _area:
		if is_instance_valid(cell) and not cells.has(cell):
			cell.highlight(0.0)
	for cell in cells:
		if hovered.has(cell):
			cell.highlight(AREA_HOVER_ALPHA, AREA_HOVER_COLOR)
		else:
			cell.highlight(AREA_ALPHA, AREA_COLOR)
	_area = cells

func _placement_error(cells : Array[Cell]) -> PlacementError:
	if cells.is_empty():
		return PlacementError.BLOCKED
	if not _preview.can_place_at(grid, cells):
		return PlacementError.OUT_OF_AREA
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
		if error == PlacementError.OUT_OF_AREA:
			print(_preview.placement_hint())
		placement_failed.emit(error)
		return
	var site : Building = _scene.instantiate()
	grid.place(site, cells)
	site.completed.connect(func(): building_completed.emit(site))
	site.start_construction()
	building_placed.emit(site)
	end_build()

func _clear_preview() -> void:
	_show_area([])
	if _preview != null:
		_preview.queue_free()
		_preview = null
