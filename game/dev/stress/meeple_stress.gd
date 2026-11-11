extends Node2D
## The meeple stress scene: thousands of meeples wander on a flat grid, all
## of them in view, on the real simulation.
##
## This is the run of issue #64. A [Village] with a [VillageMeeples] part is
## ticked by the Game service, and a [MeepleView] draws it through the sprite
## batch. It measures by the rule in issue #57, with [FrameMeter], and prints
## one table line per run. Run it in a window, not headless:
## [codeblock]
## godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     "res://game/dev/stress/meeple_stress.tscn" -- meeples=5000,5000,5000 quit=1
## [/codeblock]
## Other arguments: [code]cells=100000[/code] sets the size of the grid,
## [code]hangouts=300[/code] adds huts for the meeples to stroll around,
## [code]speed=3[/code] sets the game speed, [code]seed=64[/code] the seed,
## [code]shot=/path.png[/code] saves a picture of the last run, and
## [code]close_shot=/path.png[/code] saves one from close up.
## [code]column_width=960[/code] sets how wide the batch's mover columns are,
## in pixels. With the whole grid in view the batch looks at every column of
## every band in every frame, so wider columns cost it less here.
##
## "Run counts" is only yes for a 1920x1080 window with vsync off in which
## every frame was drawn. "Holds 60" is only yes for a run that counts.

## The window the rule asks for. The whole grid is put in view.
const WINDOW := Vector2(1920.0, 1080.0)
## How much of the window the grid fills.
const FILL := 0.97
## The colour of the flat ground.
const GROUND := Color(0.33, 0.45, 0.28)
## Before the measuring starts the village runs this many ticks, so the crowd
## is spread between standing and strolling as it is in a long game. A new
## meeple stands for up to 3.5 seconds first.
const SETTLE_TICKS := 400
## The share of the meeples that carry something, so every head is drawn.
const LOADED := 0.3
## The load kinds of this scene, and the name the look has for each.
const LOAD_NAMES: Dictionary[int, StringName] = {1: &"wood", 2: &"stone"}
## The table columns: the key in a result, and its heading.
const COLUMNS: Dictionary[String, String] = {
	"meeples": "Meeples",
	"cells": "Cells",
	"hangouts": "Hangouts",
	"average_ms": "Average ms",
	"p95_ms": "95th ms",
	"worst_ms": "Worst ms",
	"fps": "Frames a second",
	"run_counts": "Run counts",
	"holds_60": "Holds 60",
	"every_frame_drawn": "Every frame drawn",
	"ticks_a_second": "Ticks a second",
	"walking": "Walking",
	"stepped_a_tick": "Stepped a tick",
	"tick_ms": "Ms a tick",
	"worst_tick_ms": "Worst tick ms",
	"sim_ms": "Sim ms",
	"view_ms": "View ms",
	"batch_ms": "Batch ms",
	"render_cpu_ms": "Render ms",
	"draw_calls": "Draw calls",
	"sprites_sent": "Sprites sent",
}


## Sets up one meeple of the crowd: adds it, and gives some of them a load.
class AddToCrowd:
	extends VillageCommand
	var spot: Vector2
	var load_kind: int
	var load_count: int

	func _init(at: Vector2, kind: int, count: int) -> void:
		spot = at
		load_kind = kind
		load_count = count

	## Adds the meeple with its load.
	func apply(village: Village) -> bool:
		var meeples := village.part(Village.MEEPLES) as VillageMeeples
		var meeple := meeples.spawn(village, spot)
		return meeples.carry(meeple, load_kind, load_count)


## Stands a hut of 2 by 2 cells on the grid and makes it a hangout.
class AddHut:
	extends VillageCommand
	var anchor: Vector2i
	var thing: int = 0

	func _init(at: Vector2i) -> void:
		anchor = at

	## Places the hut. Refused when the cells are taken.
	func apply(village: Village) -> bool:
		var meeples := village.part(Village.MEEPLES) as VillageMeeples
		var id := village.new_id()
		if not village.grid.place(id, anchor, 2, 2):
			return false
		thing = id
		return meeples.wander.add_hangout(village, id)


var _counts: Array[int] = [5000]
var _cells := 100000
var _hangouts := 0
var _speed := 1.0
var _seed := 64
var _column_width := 960.0
var _shot := ""
var _close_shot := ""
var _quit := false

var _art := StressArt.new()
var _look := MeepleLook.new()
var _area := Rect2()
var _village: Village
var _meeples: VillageMeeples
var _batch: SpriteBatch
var _view: MeepleView
var _camera := Camera2D.new()
var _ground := Polygon2D.new()
var _meter := FrameMeter.new()
var _label := Label.new()

var _ticks := 0
var _walking := 0
var _tick_usec := 0
var _worst_tick_usec := 0


func _ready() -> void:
	_read_arguments()
	# This scene calls Game.advance itself, so it can time the ticks.
	Game.set_process(false)
	add_child(_meter)
	_meter.prepare()
	_ground.color = GROUND
	add_child(_ground)
	add_child(_camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label.position = Vector2(16.0, 16.0)
	layer.add_child(_label)
	_run.call_deferred()


func _exit_tree() -> void:
	Game.end_session()
	Game.set_process(true)


func _process(delta: float) -> void:
	if _village == null:
		return
	var started := Time.get_ticks_usec()
	var ticks := Game.advance(delta)
	var spent := Time.get_ticks_usec() - started
	if ticks > 0:
		_ticks += ticks
		_walking += _meeples.walkers.size() * ticks
		_tick_usec += spent
		@warning_ignore("integer_division")
		_worst_tick_usec = maxi(_worst_tick_usec, spent / ticks)
	_meter.add("sim_ms", spent / 1000.0)
	# The view and the batch run after this node, so these are last frame's times.
	_meter.add("view_ms", _view.frame_usec() / 1000.0)
	_meter.add("batch_ms", _batch.prepare_usec() / 1000.0)


func _read_arguments() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() != 2:
			continue
		match pair[0]:
			"meeples":
				_counts.clear()
				for count in pair[1].split(","):
					_counts.append(int(count))
			"cells":
				_cells = int(pair[1])
			"hangouts":
				_hangouts = int(pair[1])
			"speed":
				_speed = float(pair[1])
			"seed":
				_seed = int(pair[1])
			"column_width":
				_column_width = float(pair[1])
			"shot":
				_shot = pair[1]
			"close_shot":
				_close_shot = pair[1]
			"quit":
				_quit = pair[1] == "1"


## Builds a fresh village with [param count] meeples, and its picture.
func _build(count: int) -> void:
	if _view != null:
		_view.free()
		_batch.free()
	Game.new_session()
	Game.speed = _speed
	_village = Game.new_village(_seed)
	_meeples = VillageMeeples.new()
	_village.add_part(Village.MEEPLES, _meeples)
	_lay_grid()
	var atlas := SpriteAtlas.new()
	_art.add_to(atlas)
	_look.add_to(atlas)
	atlas.build()
	var pixels := Rect2(_area.position * JamGrid.ART_SCALE, _area.size * JamGrid.ART_SCALE)
	var rows := BatchRows.new(
		JamGrid.cells(), atlas, pixels.grow(200.0), JamGrid.ART_SCALE, _column_width
	)
	_look.shape(rows)
	_batch = SpriteBatch.new()
	_batch.setup(rows, MeepleLook.SHADER)
	_look.dress(_batch)
	add_child(_batch)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	_add_huts(rng, rows)
	_add_crowd(rng, count)
	for tick in SETTLE_TICKS:
		_village.tick()
	_view = MeepleView.new()
	_view.load_names = LOAD_NAMES
	_view.setup(_meeples, _batch, _look)
	add_child(_view)
	_ground.polygon = PackedVector2Array([
		pixels.position, Vector2(pixels.end.x, pixels.position.y),
		pixels.end, Vector2(pixels.position.x, pixels.end.y),
	])
	_camera.position = pixels.get_center()
	var zoom := minf(WINDOW.x / pixels.size.x, WINDOW.y / pixels.size.y) * FILL
	_camera.zoom = Vector2(zoom, zoom)


## Makes the flat grid: every cell whose place is inside an area as wide as
## the window is, so all of it fits in view. The grid is slanted, so each row
## starts a bit further left than the row above it.
func _lay_grid() -> void:
	var cell_area := float(GridLayout.CELL_WIDTH * GridLayout.ROW_HEIGHT)
	var height := sqrt(_cells * cell_area * WINDOW.y / WINDOW.x)
	_area = Rect2(0.0, 0.0, height * WINDOW.x / WINDOW.y, height)
	var grid := _village.grid
	for y in range(0, floori(_area.size.y / GridLayout.ROW_HEIGHT) + 1):
		var shift := y * GridLayout.ROW_SHIFT
		var first := ceili(-shift / float(GridLayout.CELL_WIDTH))
		var last := floori((_area.size.x - shift) / GridLayout.CELL_WIDTH)
		for x in range(first, last + 1):
			grid.add_cell(Vector2i(x, y))


func _add_huts(rng: RandomNumberGenerator, rows: BatchRows) -> void:
	var placed := 0
	for attempt in _hangouts * 20:
		if placed >= _hangouts:
			break
		var hut := AddHut.new(_village.grid.cell_at(_random_spot(rng)))
		if _village.send(hut):
			rows.add_thing(hut.thing, hut.anchor, _art.sprites[&"hut"], _art.offset_of(&"hut"))
			placed += 1


func _add_crowd(rng: RandomNumberGenerator, count: int) -> void:
	for index in count:
		var kind := VillageMeeples.NO_LOAD
		var pieces := 0
		if rng.randf() < LOADED:
			kind = rng.randi_range(1, 2)
			pieces = rng.randi_range(1, 2)
		_village.send(AddToCrowd.new(_random_spot(rng), kind, pieces))


## A random spot on the grid, away from its edge.
func _random_spot(rng: RandomNumberGenerator) -> Vector2:
	var inside := _area.grow(-12.0)
	return inside.position + Vector2(rng.randf(), rng.randf()) * inside.size


func _run() -> void:
	var results: Array[Dictionary] = []
	_label.visible = false
	var screen := "MEEPLE_STRESS_SCREEN the screen refreshes %s times a second, vsync is %s" % [
		snappedf(_meter.screen_refresh_rate(), 0.1), "off" if _meter.vsync_is_off() else "ON",
	]
	print(screen)
	for count in _counts:
		_build(count)
		_ticks = 0
		_walking = 0
		_tick_usec = 0
		_worst_tick_usec = 0
		var steps_before := _meeples.steps
		var started := Time.get_ticks_usec()
		var result := await _meter.measure()
		var seconds := (Time.get_ticks_usec() - started) / 1000000.0
		var ticks := maxi(_ticks, 1)
		result["meeples"] = _meeples.count()
		result["cells"] = _village.grid.cell_count()
		result["hangouts"] = _meeples.wander.hangout_count()
		result["sprites_sent"] = _batch.sprites_sent()
		result["ticks_a_second"] = snappedf(_ticks / seconds, 0.1)
		@warning_ignore("integer_division")
		result["walking"] = _walking / ticks
		@warning_ignore("integer_division")
		result["stepped_a_tick"] = (_meeples.steps - steps_before) / ticks
		result["tick_ms"] = snappedf(_tick_usec / 1000.0 / ticks, 0.01)
		result["worst_tick_ms"] = snappedf(_worst_tick_usec / 1000.0, 0.01)
		results.append(result)
		print("MEEPLE_STRESS_RESULT ", JSON.stringify(result))
	var table := FrameMeter.table(results, COLUMNS)
	print("MEEPLE_STRESS_TABLE\n", table)
	await _save_pictures()
	var lines := PackedStringArray([table.replace("|", "  ")])
	lines.append(screen.trim_prefix("MEEPLE_STRESS_SCREEN "))
	_label.text = "\n".join(lines)
	_label.visible = true
	print("MEEPLE_STRESS_DONE")
	if _quit:
		get_tree().quit()


func _save_pictures() -> void:
	if _shot != "":
		await _save_picture(_shot)
	if _close_shot != "":
		# From close up: one art pixel is 5 screen pixels.
		_camera.zoom = Vector2(0.5, 0.5)
		await _save_picture(_close_shot)


func _save_picture(path: String) -> void:
	for frame in 3:
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(path)
	print("MEEPLE_STRESS_SHOT ", path)
