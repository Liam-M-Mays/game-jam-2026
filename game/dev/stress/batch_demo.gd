extends Node2D
## A small village-sized scene to look at the sprite batch: static things on
## the slanted grid, wandering meeples, and the mouse finding things with maths.
##
## Open [code]batch_demo.tscn[/code] and press F6.
## - Move with WASD or the arrow keys. Zoom with the mouse wheel.
## - The thing under the mouse turns yellow, and its cell is outlined.
## - Left click a thing to take it away. Left click an empty cell to plant a tree.
## - Press M for 500 more meeples.
##
## From a terminal, [code]-- shot=/path.png[/code] saves a picture after two
## seconds and closes the scene.

## How many cells the demo grid has across and down.
const GRID := Vector2i(60, 40)
## How many meeples wander about at the start.
const MEEPLES := 300
## The share of the cells that get a static thing.
const FILL := 0.25
## The share of each kind among the static things.
const MIX: Dictionary[StringName, float] = {
	&"tree": 0.36, &"big_tree": 0.12, &"rock": 0.24, &"big_rock": 0.08,
	&"wood": 0.08, &"stone": 0.08, &"hut": 0.03, &"town_hall": 0.01,
}
## The colour of the thing under the mouse.
const HOVER_TINT := Color(1.0, 0.9, 0.35)
## The outline of one cell, in art pixels around the cell's position. From the
## jam game, assets/Scripts/Env/grid.gd.
const CELL_OUTLINE: Array[Vector2] = [
	Vector2(4, 2), Vector2(4, 1), Vector2(1, -2), Vector2(-5, -2), Vector2(-5, -1), Vector2(-2, 2),
]
## How fast the camera moves, in screen pixels a second.
const PAN_SPEED := 900.0
## How much one click of the mouse wheel zooms.
const ZOOM_STEP := 1.25
## The furthest and the closest zoom.
const ZOOM_LIMITS := Vector2(0.125, 8.0)

var _art := StressArt.new()
var _look := MeepleLook.new()
var _cells := BatchCells.new()
var _rows: BatchRows
var _batch: SpriteBatch
var _crowd: WanderCrowd
var _camera := Camera2D.new()
var _label := Label.new()
var _rng := RandomNumberGenerator.new()

var _kinds: Dictionary[int, StringName] = {}
var _thing_cells: Dictionary[int, Vector2i] = {}
var _next_id := 0
var _hovered := BatchRows.NO_THING
var _mouse_cell := Vector2i.ZERO
var _last_click := "nothing yet"


func _ready() -> void:
	_rng.seed = 61
	var far_corner := _cells.position_of(GRID - Vector2i.ONE)
	var world := Rect2(Vector2.ZERO, far_corner)
	var atlas := SpriteAtlas.new()
	_art.add_to(atlas)
	_look.add_to(atlas)
	atlas.build()
	_rows = BatchRows.new(_cells, atlas, world)
	_look.shape(_rows)
	_batch = SpriteBatch.new()
	_batch.setup(_rows, MeepleLook.SHADER)
	_look.dress(_batch)
	add_child(_batch)
	for row in GRID.y:
		for column in GRID.x:
			if _rng.randf() < FILL:
				_plant(Vector2i(column, row), _pick_kind())
	# The meeples stay on the slanted block of cells, away from its thin ends.
	var inner := Rect2(far_corner.x * 0.3, 0.0, far_corner.x * 0.4, far_corner.y)
	_crowd = WanderCrowd.new(inner, _rows, _look, 62)
	_crowd.grow_to(MEEPLES)
	_camera.position = world.get_center()
	add_child(_camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label.position = Vector2(16.0, 12.0)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			_save_picture.call_deferred(arg.trim_prefix("shot="))


func _process(delta: float) -> void:
	_crowd.step(delta)
	var push := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	push += Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	_camera.position += push.limit_length(1.0) * PAN_SPEED * delta / _camera.zoom.x
	_hover()
	queue_redraw()
	_label.text = _status()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(1.0 / ZOOM_STEP)
			MOUSE_BUTTON_LEFT:
				_click(button.position)
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_M:
		_crowd.grow_to(_crowd.count() + 500)


func _draw() -> void:
	var outline := PackedVector2Array()
	var at := _cells.position_of(_mouse_cell)
	for corner in CELL_OUTLINE:
		outline.append(at + corner * _rows.pixel_scale)
	outline.append(outline[0])
	draw_polyline(outline, Color(1.0, 1.0, 1.0, 0.8), 2.0)


## The thing under the mouse turns yellow. Hover and click ask the batch the
## same question.
func _hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	_mouse_cell = _cells.cell_at(_batch.to_world(mouse))
	var found := _batch.thing_at_screen(mouse)
	if found == _hovered:
		return
	if _rows.has_thing(_hovered):
		_rows.tint_thing(_hovered, Color.WHITE)
	_hovered = found
	if found != BatchRows.NO_THING:
		_rows.tint_thing(found, HOVER_TINT)


func _click(screen_point: Vector2) -> void:
	var found := _batch.thing_at_screen(screen_point)
	var cell := _cells.cell_at(_batch.to_world(screen_point))
	if found != BatchRows.NO_THING:
		_last_click = "took away the %s on cell %s" % [_kinds[found], _thing_cells[found]]
		_rows.remove_thing(found)
		if _rows.has_thing(_hovered):
			_rows.tint_thing(_hovered, Color.WHITE)
		_hovered = BatchRows.NO_THING
	elif cell.x >= 0 and cell.y >= 0 and cell.x < GRID.x and cell.y < GRID.y:
		_plant(cell, &"tree")
		_last_click = "planted a tree on cell %s" % cell
	else:
		_last_click = "nothing there"


func _save_picture(path: String) -> void:
	await get_tree().create_timer(2.0).timeout
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _plant(cell: Vector2i, kind: StringName) -> void:
	_rows.add_thing(_next_id, cell, _art.sprites[kind], _art.offset_of(kind))
	_kinds[_next_id] = kind
	_thing_cells[_next_id] = cell
	_next_id += 1


func _pick_kind() -> StringName:
	var roll := _rng.randf()
	for kind: StringName in MIX:
		roll -= MIX[kind]
		if roll < 0.0:
			return kind
	return &"tree"


func _zoom_by(factor: float) -> void:
	var zoom := clampf(_camera.zoom.x * factor, ZOOM_LIMITS.x, ZOOM_LIMITS.y)
	_camera.zoom = Vector2(zoom, zoom)


func _status() -> String:
	var under := "nothing"
	if _hovered != BatchRows.NO_THING:
		under = "%s (thing %d) on cell %s" % [_kinds[_hovered], _hovered, _thing_cells[_hovered]]
	var total := _rows.thing_count() + _rows.mover_count()
	return "\n".join([
		"WASD or arrows: move.  Mouse wheel: zoom.  Left click: take away or plant.  M: more meeples.",
		"Under the mouse: %s.  Cell under the mouse: %s." % [under, _mouse_cell],
		"Last click: %s.  Row %d was rebuilt %d times."
		% [_last_click, _mouse_cell.y, _rows.row_version(_mouse_cell.y)],
		"Sprites sent this frame: %d of %d.  Meeples: %d.  Frames a second: %d."
		% [_batch.sprites_sent(), total, _rows.mover_count(), Engine.get_frames_per_second()],
	])
