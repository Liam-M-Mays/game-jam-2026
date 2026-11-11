extends Node2D
## The new game scene: one village on a generated ground world, drawn by the
## sprite batch.
##
## It starts a session, picks the world seed, makes the village and its
## world, and puts the picture on screen. Later parts add to it: meeples,
## buildings, the HUD.
##
## The camera here is a stand-in until the camera part (#72):
## WASD or the arrow keys move, the mouse wheel zooms.

## The zoom at the start: 8 screen pixels per art pixel, as in the jam game.
const START_ZOOM := 0.8
## The furthest and the closest zoom of the stand-in camera. The furthest
## shows the whole world of 100,000 cells.
const ZOOM_LIMITS := Vector2(0.04, 2.0)
## How much one click of the mouse wheel zooms.
const ZOOM_STEP := 1.1
## How fast the stand-in camera moves, in screen pixels a second.
const PAN_SPEED := 1000.0

## The dev settings this game reads its world size and its fixed seed from.
## Leave it empty for the saved ones. A test sets its own before the scene
## enters the tree.
var settings: DevSettings
## The village of this game.
var village: Village
## The picture of the village.
var view: VillageView

var _camera: Camera2D


func _ready() -> void:
	if settings == null:
		settings = DevSettings.load_settings()
	var world_seed := WorldSeed.pick(settings.world_seed)
	print(WorldSeed.line(world_seed))
	Game.new_session()
	village = Game.new_village(world_seed)
	var world := WorldGenerator.generate(village, settings.world_cells)
	if world == null:
		push_error("GameScene: no world was made. world_cells is %d" % settings.world_cells)
		set_process(false)
		set_process_unhandled_input(false)
		return
	Game.show_village(village)
	view = VillageView.new()
	view.name = "VillageView"
	add_child(view)
	view.attach(village, world.bounds, VillageLayers.of(village))
	_camera = Camera2D.new()
	_camera.position = VillageView.to_pixels(GridLayout.position_of(world.start_cell))
	_camera.zoom = Vector2(START_ZOOM, START_ZOOM)
	add_child(_camera)


func _exit_tree() -> void:
	if view != null:
		view.detach()
	Game.end_session()


func _process(delta: float) -> void:
	var push := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	push += Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	_camera.position += push.limit_length(1.0) * PAN_SPEED * delta / _camera.zoom.x


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_by(ZOOM_STEP)
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_by(1.0 / ZOOM_STEP)


func _zoom_by(factor: float) -> void:
	var zoom := clampf(_camera.zoom.x * factor, ZOOM_LIMITS.x, ZOOM_LIMITS.y)
	_camera.zoom = Vector2(zoom, zoom)
