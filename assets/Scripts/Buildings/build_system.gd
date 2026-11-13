extends Node2D
class_name BuildSystem

signal build_started(scene : PackedScene)
signal build_ended
signal building_placed(building : Building)
signal building_completed(building : Building)
signal placement_failed(reason : PlacementError, hint : String)

enum PlacementError { NONE, BLOCKED, CANT_AFFORD, OUT_OF_AREA }

const GROUP := &"build_system"

## Land a barn keeps for farms and silos: the barn being placed, or the land farms and silos can go on.
const AREA_COLOR := Color(1.0, 0.95, 0.6, 0.7)
## The land of the barns already built, while placing a barn, so they can be lined up.
const OTHER_AREA_COLOR := Color(1.0, 0.95, 0.6, 0.35)
const AREA_TAKEN_COLOR := Color(1.0, 0.35, 0.3, 0.7)
## The cells right next to the building, so the player sees the grid around it.
const NEAR_COLOR := Color(Cell.HIGHLIGHT_COLOR, 0.5)
## The cells the building will stand on: green where it fits, red where it does not.
const FITS_COLOR := Color(0.45, 1.0, 0.45, 0.9)
const BLOCKED_COLOR := Color(1.0, 0.3, 0.25, 0.9)
const PAUSE_CLICK_MAX_DRAG := 6.0

@export var grid : Grid

var _scene : PackedScene = null
var _preview : Building = null
var _lit : Array[Cell] = []
var _right_press_at := Vector2.ZERO
var _tooltip := ConstructionTooltip.new()
## The building the player is moving. It is lifted off its cells until it lands or goes back.
var _moving : Building = null

func _ready() -> void:
	add_to_group(GROUP)
	add_child(_tooltip)

func start_build(scene : PackedScene) -> void:
	var preview : Building = scene.instantiate()
	if preview.restricts_placement() and preview.placement_area(grid).is_empty():
		placement_failed.emit(PlacementError.OUT_OF_AREA, preview.placement_hint())
		preview.free()
		return
	_put_back()
	_clear_preview()
	_scene = scene
	_preview = preview
	grid.add_child(_preview)
	_preview.show_as_preview()
	build_started.emit(scene)

func end_build() -> void:
	if not is_building():
		return
	_put_back()
	_clear_preview()
	_scene = null
	build_ended.emit()

func is_building() -> bool:
	return _preview != null

## The panel's Move button. Picks `building` up into the same placing as a new one, with the same rules but free.
## A click puts it down, and Escape or a right click puts it back where it was.
func start_move(building : Building) -> void:
	start_build(load(building.scene_file_path))
	if is_building():
		_moving = building
		building.lift()

func _put_back() -> void:
	if _moving != null:
		_moving.land(_moving.cells)
		_moving = null

## The placing rules come from the building being moved, so it may overlap its old spot, or else from the preview.
func _rules() -> Building:
	return _moving if _moving != null else _preview

func _input(event : InputEvent) -> void:
	if is_building() and event.is_action_pressed("ui_cancel"):
		end_build()
		get_viewport().set_input_as_handled()

func _unhandled_input(event : InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_on_right_button(event)
	elif is_building() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_place()
		get_viewport().set_input_as_handled()

func _on_right_button(event : InputEventMouseButton) -> void:
	if event.pressed:
		_right_press_at = event.position
	elif event.position.distance_to(_right_press_at) <= PAUSE_CLICK_MAX_DRAG:
		if _moving != null:
			end_build()
			return
		var site := ConstructionTooltip.site_under_mouse(get_tree())
		if site != null:
			site.toggle_paused()

func _process(_delta : float) -> void:
	if not is_building():
		return
	var mouse := get_global_mouse_position()
	var anchor := grid.cell_at(mouse)
	_tooltip.note = _rules().note()
	_preview.visible = anchor != null
	if anchor == null:
		_show_lights({})
		return
	_preview.position = anchor.position
	var cells := grid.free_cells_at(mouse, _preview.footprint, _preview.footprint_depth)
	var blocked := _placement_error(cells) != PlacementError.NONE
	_preview.set_preview_blocked(blocked)
	var lights := _area_lights(anchor)
	var under := grid.cells_under(mouse, _preview.footprint, _preview.footprint_depth)
	for cell in grid.cells_next_to(under):
		if not lights.has(cell):
			lights[cell] = NEAR_COLOR
	for cell in under:
		lights[cell] = BLOCKED_COLOR if blocked else FITS_COLOR
	_show_lights(lights)

## The land to show around the building: where a farm or silo may go, or a barn's plot area and the other barns' areas.
func _area_lights(anchor : Cell) -> Dictionary[Cell, Color]:
	var lights : Dictionary[Cell, Color] = {}
	if _preview.restricts_placement():
		for cell in _preview.placement_area(grid):
			lights[cell] = AREA_COLOR
		return lights
	if _preview is Barn:
		for barn : Barn in get_tree().get_nodes_in_group(Barn.GROUP):
			if barn != _moving:
				for cell in barn.area_at(grid, barn.cells[0]):
					lights[cell] = OTHER_AREA_COLOR
	for cell in _preview.area_at(grid, anchor):
		var taken := cell.occupant != null or (cell.kept_for != null and cell.kept_for != _moving)
		lights[cell] = AREA_TAKEN_COLOR if taken else AREA_COLOR
	return lights

func _show_lights(lights : Dictionary[Cell, Color]) -> void:
	for cell in _lit:
		if is_instance_valid(cell) and not lights.has(cell):
			cell.highlight(0.0)
	for cell in lights:
		cell.highlight(lights[cell].a, lights[cell])
	_lit.assign(lights.keys())

func _placement_error(cells : Array[Cell]) -> PlacementError:
	if cells.is_empty():
		return PlacementError.BLOCKED
	if not _rules().can_place_at(grid, cells):
		return PlacementError.OUT_OF_AREA
	if _moving == null and not _preview.can_afford():
		return PlacementError.CANT_AFFORD
	return PlacementError.NONE

func _try_place() -> void:
	var cells := grid.free_cells_at(get_global_mouse_position(), _preview.footprint, _preview.footprint_depth)
	var error := _placement_error(cells)
	if error != PlacementError.NONE:
		_preview.reject()
		var hint := _rules().placement_hint() if error == PlacementError.OUT_OF_AREA else ""
		placement_failed.emit(error, hint)
		return
	if _moving != null:
		_moving.land(cells)
		_moving = null
		end_build()
		return
	var site : Building = _scene.instantiate()
	grid.place(site, cells)
	site.completed.connect(func(): building_completed.emit(site))
	site.start_construction()
	VillageAudio.play(&"hammer", site.global_position)
	building_placed.emit(site)
	var next := site.build_after(_scene)
	end_build()
	if next != null:
		start_build(next)

func _clear_preview() -> void:
	_show_lights({})
	_tooltip.note = ""
	if _preview != null:
		_preview.queue_free()
		_preview = null
