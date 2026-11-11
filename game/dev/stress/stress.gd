extends Node2D
## The batch stress scene: wandering meeples and static things, all in view.
##
## It measures by the rule in issue #57, with [FrameMeter], and prints one
## table line per run. Run it in a window, not headless:
## [codeblock]
## godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     "res://game/dev/stress/stress.tscn" -- meeples=5000,10000 statics=6000 quit=1
## [/codeblock]
## Other arguments: [code]churn=30[/code] sets how many drops are taken away
## and put back each frame, and [code]shot=/path.png[/code] saves a picture
## of the last run.
##
## "Run counts" is only yes for a 1920x1080 window with vsync off in which
## every frame was drawn. "Holds 60" is only yes for a run that counts.
## "Wander ms" is this scene's stand-in for the simulation, "Batch ms" is the
## script time of the sprite batch, and "Render ms" is Godot's drawing time on
## the processor. The rest of a frame is spent handing the picture to the screen.

## The area the meeples wander in. At zoom 0.25 it fills a 1920x1080 window.
const AREA := Vector2(7680.0, 4320.0)
## The camera zoom that puts all of [constant AREA] in view.
const ZOOM := 0.25
## The share of each kind among the static things.
const MIX: Dictionary[StringName, float] = {
	&"tree": 0.25, &"big_tree": 0.10, &"rock": 0.20, &"big_rock": 0.05,
	&"wood": 0.15, &"stone": 0.15, &"hut": 0.08, &"town_hall": 0.02,
}
## The table columns: the key in a result, and its heading.
const COLUMNS: Dictionary[String, String] = {
	"meeples": "Meeples",
	"statics": "Static things",
	"sprites_sent": "Sprites sent",
	"average_ms": "Average ms",
	"p95_ms": "95th ms",
	"worst_ms": "Worst ms",
	"fps": "Frames a second",
	"run_counts": "Run counts",
	"holds_60": "Holds 60",
	"every_frame_drawn": "Every frame drawn",
	"wander_ms": "Wander ms",
	"batch_ms": "Batch ms",
	"render_cpu_ms": "Render ms",
	"draw_calls": "Draw calls",
}

var _counts: Array[int] = [5000, 10000]
var _statics := 6000
var _churn := 30
var _shot := ""
var _quit := false
var _rng := RandomNumberGenerator.new()

var _art := StressArt.new()
var _look := MeepleLook.new()
var _cells := JamGrid.cells()
var _rows: BatchRows
var _batch: SpriteBatch
var _crowd: WanderCrowd
var _meter := FrameMeter.new()
var _label := Label.new()

var _free_cells: Array[Vector2i] = []
var _drops: Array[int] = []
var _drop_cells: Dictionary[int, Vector2i] = {}
var _drop_kinds: Dictionary[int, StringName] = {}
var _warnings := PackedStringArray()


func _ready() -> void:
	_read_arguments()
	_rng.seed = 12345
	add_child(_meter)
	_meter.prepare()
	var camera := Camera2D.new()
	camera.position = AREA * 0.5
	camera.zoom = Vector2(ZOOM, ZOOM)
	add_child(camera)
	_build_batch()
	_place_statics()
	var layer := CanvasLayer.new()
	add_child(layer)
	_label.position = Vector2(16.0, 16.0)
	layer.add_child(_label)
	_run.call_deferred()


func _process(delta: float) -> void:
	if _crowd.count() == 0:
		return
	var started := Time.get_ticks_usec()
	_crowd.wander_only(delta)
	var wandered := Time.get_ticks_usec()
	_churn_drops()
	_rows.move_movers(_crowd.spots)
	var moved := Time.get_ticks_usec()
	# "Wander" is this scene's stand-in for the simulation. "Batch" is the
	# sprite batch: moving the meeples, the drops that come and go, and the
	# work it does just before the frame is drawn.
	_meter.add("wander_ms", (wandered - started) / 1000.0)
	_meter.add("batch_ms", (moved - wandered + _batch.prepare_usec()) / 1000.0)


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
			"statics":
				_statics = int(pair[1])
			"churn":
				_churn = int(pair[1])
			"shot":
				_shot = pair[1]
			"quit":
				_quit = pair[1] == "1"


func _build_batch() -> void:
	var atlas := SpriteAtlas.new()
	_art.add_to(atlas)
	_look.add_to(atlas)
	atlas.build()
	_rows = BatchRows.new(_cells, atlas, Rect2(Vector2.ZERO, AREA), JamGrid.ART_SCALE)
	_look.shape(_rows)
	_batch = SpriteBatch.new()
	_batch.setup(_rows, MeepleLook.SHADER)
	_look.dress(_batch)
	add_child(_batch)
	_crowd = WanderCrowd.new(Rect2(Vector2.ZERO, AREA), _rows, _look)


func _place_statics() -> void:
	var last_row := _cells.band_at(AREA.y) - 1
	for row in range(2, last_row + 1):
		var first := ceili((0.0 - row * _cells.slant_x) / _cells.step_x)
		var last := floori((AREA.x - row * _cells.slant_x) / _cells.step_x)
		for column in range(first, last + 1):
			_free_cells.append(Vector2i(column, row))
	if _statics > _free_cells.size():
		_warn("only %d static things fit in view, not %d" % [_free_cells.size(), _statics])
	for id in mini(_statics, _free_cells.size()):
		var kind := _pick_kind()
		var cell := _take_free_cell()
		_rows.add_thing(id, cell, _art.sprites[kind], _art.offset_of(kind))
		if kind == &"wood" or kind == &"stone":
			_drops.append(id)
			_drop_cells[id] = cell
			_drop_kinds[id] = kind
	if _drops.is_empty() or _free_cells.is_empty() or _churn <= 0:
		_warn("no drops come and go in this run, so no row is rebuilt while it measures")


func _warn(text: String) -> void:
	_warnings.append(text)
	print("STRESS_WARNING ", text)


func _pick_kind() -> StringName:
	var roll := _rng.randf()
	for kind: StringName in MIX:
		roll -= MIX[kind]
		if roll < 0.0:
			return kind
	return &"tree"


func _take_free_cell() -> Vector2i:
	var at := _rng.randi_range(0, _free_cells.size() - 1)
	var cell := _free_cells[at]
	_free_cells[at] = _free_cells[_free_cells.size() - 1]
	_free_cells.pop_back()
	return cell


## Drops come and go while a village works. Each frame a few are taken away
## and put back on another cell, so rows are rebuilt during the measuring.
func _churn_drops() -> void:
	if _drops.is_empty() or _free_cells.is_empty():
		return
	for step in _churn:
		var id := _drops[_rng.randi_range(0, _drops.size() - 1)]
		_rows.remove_thing(id)
		_free_cells.append(_drop_cells[id])
		var cell := _take_free_cell()
		var kind := _drop_kinds[id]
		_rows.add_thing(id, cell, _art.sprites[kind], _art.offset_of(kind))
		_drop_cells[id] = cell


func _run() -> void:
	var results: Array[Dictionary] = []
	_label.visible = false
	var screen := "STRESS_SCREEN the screen refreshes %s times a second, vsync is %s" % [
		snappedf(_meter.screen_refresh_rate(), 0.1), "off" if _meter.vsync_is_off() else "ON",
	]
	print(screen)
	for count in _counts:
		_crowd.grow_to(count)
		var result := await _meter.measure()
		result["meeples"] = count
		result["statics"] = _rows.thing_count()
		result["sprites_sent"] = _batch.sprites_sent()
		results.append(result)
		print("STRESS_RESULT ", JSON.stringify(result))
	var table := FrameMeter.table(results, COLUMNS)
	print("STRESS_TABLE\n", table)
	if _shot != "":
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(_shot)
		print("STRESS_SHOT ", _shot)
	var lines := PackedStringArray([table.replace("|", "  "), screen.trim_prefix("STRESS_SCREEN ")])
	for warning in _warnings:
		lines.append("Warning: " + warning)
	_label.text = "\n".join(lines)
	_label.visible = true
	print("STRESS_DONE")
	if _quit:
		get_tree().quit()
