extends Node2D
## Shows a whole ground world, to look at its shape and at where each kind of
## tree, rock and bush stands.
##
## Open [code]world_look.tscn[/code] and press F6.
## - N makes the next world, from the next seed.
## - B shows the bands of the noise as colours, or the flat ground.
## - M shows the map: every thing as a dot in the colour of its kind.
## - H jumps between the whole world and the start cell.
## - WASD or the arrow keys move. The mouse wheel zooms.
##
## From a terminal, after [code]--[/code]: [code]seed=7[/code],
## [code]cells=100000[/code], [code]bands=1[/code], [code]map=1[/code],
## [code]at=start[/code], [code]zoom=0.8[/code], [code]label=0[/code] and
## [code]shot=/full/path.png[/code], which saves a picture and closes.

## The colour of each kind on the map, by kind name.
const MAP_COLOURS: Dictionary[StringName, Color] = {
	&"tree": Color(1.0, 0.9, 0.2),
	&"rock": Color(1.0, 1.0, 1.0),
	&"big_tree": Color(0.1, 0.2, 0.85),
	&"bush": Color(1.0, 0.25, 0.6),
	&"big_rock": Color(0.05, 0.05, 0.05),
}
## The colour of the marks on the start cell and the cells kept clear.
const START_COLOUR := Color(0.2, 1.0, 1.0)
## The zoom of the close look at the start cell: the game's start zoom.
const CLOSE_ZOOM := 0.8
## How much one click of the mouse wheel zooms.
const ZOOM_STEP := 1.15
## The furthest and the closest zoom.
const ZOOM_LIMITS := Vector2(0.02, 4.0)
## How fast the camera moves, in screen pixels a second.
const PAN_SPEED := 1000.0
## How much of the window the whole world takes.
const WORLD_FILL := 0.94

var _seed := 1
var _cells := 0
var _bands := false
var _map := false
var _close := false
var _zoom := CLOSE_ZOOM
var _village: Village
var _world: GroundWorld
var _view: VillageView
var _ground: GroundLayer
var _marks: Node2D
var _camera: Camera2D
var _label: Label


func _ready() -> void:
	_marks = Node2D.new()
	_camera = Camera2D.new()
	_label = Label.new()
	_cells = DevSettings.load_settings().world_cells
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"seed":
				_seed = int(value)
			"cells":
				_cells = int(value)
			"bands":
				_bands = value == "1"
			"map":
				_map = value == "1"
			"at":
				_close = value == "start"
			"zoom":
				_zoom = float(value)
			"label":
				_label.visible = value != "0"
			"shot":
				shot = value
	add_child(_camera)
	_marks.z_index = 1
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label.position = Vector2(16.0, 12.0)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)
	if not _make_world():
		_marks.hide()
		set_process_unhandled_input(false)
		if shot != "":
			get_tree().quit(1)
		return
	if shot != "":
		get_window().set_flag(Window.FLAG_ALWAYS_ON_TOP, true)
		_save_picture.call_deferred(shot)


func _process(delta: float) -> void:
	var push := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	push += Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	_camera.position += push.limit_length(1.0) * PAN_SPEED * delta / _camera.zoom.x


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(ZOOM_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / ZOOM_STEP)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_N:
			_seed += 1
			_make_world()
		KEY_B:
			_bands = not _bands
			_show()
		KEY_M:
			_map = not _map
			_show()
		KEY_H:
			_close = not _close
			_aim()


## Makes the world of the seed anew, with its picture. False when no world
## was made, as for a size below 1: then it reports one line with the size.
func _make_world() -> bool:
	if _view != null:
		_view.detach()
		_view.free()
		_village.close()
	_village = Village.new(_seed)
	_world = WorldGenerator.generate(_village, _cells)
	if _world == null:
		_village.close()
		_label.text = "No world was made. cells is %d." % _cells
		push_error("WorldLook: no world was made. cells is %d" % _cells)
		return false
	print(WorldSeed.line(_seed))
	_view = VillageView.new()
	add_child(_view)
	var layers := VillageLayers.of(_village)
	_view.attach(_village, _world.bounds, layers)
	for layer in layers:
		if layer is GroundLayer:
			_ground = layer
	_show()
	_aim()
	return true


## Applies the band and map switches, and writes the label.
func _show() -> void:
	_ground.show_bands = _bands or _map
	_view.batch.visible = not _map
	_marks.queue_redraw()
	var lines := PackedStringArray([
		"N: next world.  B: bands.  M: map.  H: whole world or start cell.  WASD and wheel: look.",
		"Seed %d.  Asked for %d cells, got %d." % [_seed, _world.asked_cells, _world.cells],
	])
	var counts := PackedStringArray()
	for kind in _world.kinds:
		var kind_name := kind.kind_name
		counts.append("%s %d of %d" % [kind_name, _world.placed[kind_name], _world.wanted[kind_name]])
	lines.append("Placed: %s." % ", ".join(counts))
	if _map:
		lines.append("Map: blue big tree, black big rock, yellow tree, white rock, pink bush.")
	if _bands or _map:
		lines.append("Ground: the darker green is the dark band, the lighter green the light band.")
	lines.append("Light blue: the ring is the start cell, the boxes are the cells kept clear.")
	_label.text = "\n".join(lines)


## Points the camera at the whole world, or at the start cell.
func _aim() -> void:
	var start := VillageView.to_pixels(GridLayout.position_of(_world.start_cell))
	if _close:
		_camera.position = start
		_camera.zoom = Vector2(_zoom, _zoom)
		return
	var area := Rect2(
		VillageView.to_pixels(_world.bounds.position), VillageView.to_pixels(_world.bounds.size)
	)
	var window := get_viewport_rect().size
	var fit := minf(window.x / area.size.x, window.y / area.size.y) * WORLD_FILL
	_camera.position = area.get_center()
	_camera.zoom = Vector2(fit, fit)


## Draws the ring on the start cell and, on the map, one dot per thing.
func _draw_marks() -> void:
	var scale_now := VillageView.ART_SCALE
	if _map:
		for row in _world.thing_count():
			var kind := _world.thing_kind(row)
			var at := GridLayout.position_of(_world.thing_cell(row)) + GridLayout.CELL_MIDDLE
			var size := Vector2(GridLayout.CELL_WIDTH * kind.width, GridLayout.ROW_HEIGHT)
			var corner := at - Vector2(GridLayout.CELL_WIDTH, GridLayout.ROW_HEIGHT) * 0.5
			_marks.draw_rect(Rect2(corner * scale_now, size * scale_now), MAP_COLOURS[kind.kind_name])
	var cell_size := Vector2(GridLayout.CELL_WIDTH, GridLayout.ROW_HEIGHT)
	var line := 2.0 / _camera.zoom.x
	for cell in _world.keep_clear:
		var corner := GridLayout.position_of(cell) + GridLayout.CELL_MIDDLE - cell_size * 0.5
		_marks.draw_rect(Rect2(corner * scale_now, cell_size * scale_now), START_COLOUR, false, line)
	var start := VillageView.to_pixels(GridLayout.position_of(_world.start_cell))
	var ring := maxf(2.0 * scale_now, 9.0 / _camera.zoom.x)
	_marks.draw_arc(start, ring, 0.0, TAU, 48, START_COLOUR, line)


func _zoom_by(factor: float) -> void:
	var zoom := clampf(_camera.zoom.x * factor, ZOOM_LIMITS.x, ZOOM_LIMITS.y)
	_camera.zoom = Vector2(zoom, zoom)
	_marks.queue_redraw()


## Saves the window as a picture, says whether it was really drawn, and closes.
func _save_picture(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var before := Engine.get_frames_drawn()
	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print(
		"WORLDLOOK saved=%s size=%s frames_drawn=%d corner_colour=%s"
		% [path, image.get_size(), before, image.get_pixel(2, image.get_height() - 3)]
	)
	get_tree().quit()
