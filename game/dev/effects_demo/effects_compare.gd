extends Control
## Draws each effect twice at the same moment: once with the jam game's own
## scenes and scripts, and once with the effects toolkit in the sprite batch.
## Then it counts the pixels that differ.
##
## The jam game's picture of each pose is kept in [code]pictures/[/code] as
## the reference, so the toolkit can still be checked after the jam game is gone.
##
## Run it in a window, not headless:
## [codeblock]
## godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     "res://game/dev/effects_demo/effects_compare.tscn" -- quit=1
## [/codeblock]
## It ends with exit code 0 when no pose differs in more pixels than
## [constant EXPECTED] says, and the jam game's own picture still matches the
## saved reference. A normal run writes no file.
## [code]save=1[/code] writes the side-by-side pictures and the sheets.
## [code]update=1[/code] also writes the reference pictures again from the jam game.
## [code]only=hover[/code] runs only the poses whose name holds that text.

## The jam game's scenes. They are loaded by path, so this file still works
## when they are gone.
const OLD_TREE := "res://assets/Scenes/Resources/tree.tscn"
const OLD_HUT := "res://assets/Scenes/Buildings/hut_build.tscn"
const OLD_CELL := "res://assets/Scenes/Env/cell.tscn"
const OLD_CELL_SCRIPT := "res://assets/Scripts/Env/cell.gd"
const OLD_SPARKS := "res://assets/Scenes/Effects/break.tscn"
const OLD_CLOUD := "res://assets/Scenes/Effects/cloud.tscn"
## The hut sheet of the jam game: five build stages of 15 by 14 art pixels.
const HUT_ART := "res://assets/Art/Buildings/House_buildstates.png"
const HUT_SIZE := Vector2i(15, 14)
const HUT_STAGES := 5
const HUT_OFFSET := Vector2(3.5, -3.0)
## The jam tree: its part of the sheet, and its offset.
const TREE_REGION := Rect2i(37, 2, 6, 8)
const TREE_OFFSET := Vector2(0.0, -3.0)
## Where the pictures are kept.
const PICTURES := "res://game/dev/effects_demo/pictures/"
## The size of each picture.
const PICTURE_SIZE := Vector2i(640, 360)
## The camera zoom of most pictures: 8 screen pixels for one art pixel, as
## the jam game's camera shows the village.
const ZOOM := 0.8
## Two pixels count as the same when no channel is further apart than this,
## out of 255. The two pictures are blended in a different order, which can
## round a channel one step apart.
const TOLERANCE := 2
## The cells of the stage: the tree, the tree in front of it, and the hut,
## which takes two cells.
const TREE_CELL := Vector2i(-2, 0)
const FRONT_CELL := Vector2i(-3, 1)
const HUT_CELL := Vector2i(1, 0)
## The numbers of the three things in the batch.
const TREE := 1
const FRONT := 2
const HUT := 3
## Two more trees for a "neighbours" pose: on the cells left and right of
## the tree, on its own row.
const LEFT := 4
const RIGHT := 5
## Where the batch node is put for a "moved" pose, and how big it is drawn.
const MOVED_TO := Vector2(310.0, -170.0)
const MOVED_SCALE := 2.0
## The first number of the things that flash off screen for a "crowd" pose.
const CROWD := 100
## How far the stage reaches from cell (0, 0), in cells.
const STAGE := Vector2i(14, 6)
## A plot area for the cell pictures: three rows of four cells.
const PLOT_ORIGIN := Vector2i(-3, -3)
const PLOT_SIZE := Vector2i(4, 3)
## How many poses one sheet shows.
const POSES_PER_SHEET := 6

## The poses. "hut" is how the hut is shown: "built", "preview", or "site"
## with the stage in "stage" (-1 is a site with nothing built yet). "time" is
## how many seconds after the steps the picture is taken. Each step is what
## happens, then to which thing, then what it needs. The step "wait" lets
## that many seconds pass before the next step.
const POSES: Array[Dictionary] = [
	{"name": "rest", "steps": []},
	{"name": "grow_in_start", "steps": [["grow_in", TREE]], "time": 0.0},
	{"name": "grow_in_mid", "steps": [["grow_in", TREE]], "time": 0.15},
	{"name": "grow_in_overshoot", "steps": [["grow_in", TREE]], "time": 0.3},
	{"name": "hit_start", "steps": [["hit", TREE]], "time": 0.0},
	{"name": "hit_early", "steps": [["hit", TREE]], "time": 0.04},
	{"name": "hit_mid", "steps": [["hit", TREE]], "time": 0.1},
	{"name": "hit_late", "steps": [["hit", TREE]], "time": 0.19},
	{"name": "last_hit", "steps": [["last_hit", TREE]], "time": 0.04},
	{"name": "hover", "steps": [["hover", TREE], ["hover", HUT]]},
	{"name": "hover_far", "steps": [["hover", TREE], ["hover", HUT]], "zoom": 0.4},
	{"name": "hover_close", "steps": [["hover", TREE], ["hover", HUT]], "zoom": 1.6},
	{"name": "selected", "steps": [["select", TREE, Color.WHITE]]},
	{"name": "selected_close", "steps": [["select", TREE, Color.WHITE]], "zoom": 1.6},
	{
		"name": "selected_and_hovered",
		"steps": [["select", TREE, Color.WHITE], ["hover", TREE]],
	},
	{"name": "reject_start", "steps": [["reject", TREE], ["reject", HUT]], "time": 0.0},
	{"name": "reject_early", "steps": [["reject", TREE], ["reject", HUT]], "time": 0.04},
	{"name": "reject_mid", "steps": [["reject", TREE], ["reject", HUT]], "time": 0.1},
	{"name": "reject_late", "steps": [["reject", TREE], ["reject", HUT]], "time": 0.2},
	{"name": "pop_top", "steps": [["pop", HUT]], "time": 0.05},
	{"name": "pop_back", "steps": [["pop", HUT]], "time": 0.1},
	# A second delivery 0.03 seconds into a pop, and a second hit 0.05 seconds
	# into a hit. The jam game carries on from the size and the tilt it has.
	{"name": "pop_again", "steps": [["pop", HUT], ["wait", 0.03], ["pop", HUT]], "time": 0.01},
	{"name": "hit_again", "steps": [["hit", TREE], ["wait", 0.05], ["hit", TREE]], "time": 0.02},
	{"name": "flash_on_new_stage", "hut": "site", "stage": 2, "steps": [["flash", HUT]],
		"time": 0.04},
	{"name": "preview", "hut": "preview", "steps": []},
	{"name": "preview_blocked", "hut": "preview", "steps": [["block", HUT]]},
	{"name": "preview_reject", "hut": "preview", "steps": [["block", HUT], ["reject", HUT]],
		"time": 0.04},
	{"name": "site_empty", "hut": "site", "stage": -1, "steps": []},
	{"name": "site", "hut": "site", "stage": 1, "steps": []},
	{"name": "site_blocked", "hut": "site", "stage": 1, "steps": [["block", HUT]]},
	{"name": "site_hover", "hut": "site", "stage": 1, "steps": [["hover", HUT]]},
	{"name": "site_empty_hover", "hut": "site", "stage": -1, "steps": [["hover", HUT]]},
	{
		"name": "site_paused", "hut": "site", "stage": 1,
		"steps": [["select", HUT, JamEffects.PAUSED_OUTLINE]],
	},
	{"name": "sparks_1", "steps": [["sparks", TREE], ["remove", TREE]], "time": 0.01},
	{"name": "sparks_2", "steps": [["sparks", TREE], ["remove", TREE]], "time": 0.07},
	{"name": "sparks_3", "steps": [["sparks", TREE], ["remove", TREE]], "time": 0.13},
	{"name": "sparks_over", "steps": [["sparks", TREE], ["remove", TREE]], "time": 0.2},
	# A tree on each side, on the row of the tree that broke. The jam game
	# sorts the sparks by their own height, so these two trees cover them.
	{"name": "sparks_3_between_trees", "neighbours": true,
		"steps": [["sparks", TREE], ["remove", TREE]], "time": 0.13},
	{"name": "cloud_1", "steps": [["cloud", HUT, Vector2.ZERO]], "time": 0.01},
	{"name": "cloud_2", "steps": [["cloud", HUT, Vector2.ZERO]], "time": 0.11},
	{"name": "cloud_3_moved_down", "steps": [["cloud", HUT, Vector2(0.0, 10.0)]], "time": 0.21},
	{"name": "cloud_over", "steps": [["cloud", HUT, Vector2.ZERO]], "time": 0.31},
	{"name": "cells_round_the_mouse", "steps": [["cursor", Vector2(30.0, -20.0)]]},
	{"name": "cells_plot", "hut": "none", "steps": [["plot", false]]},
	{"name": "cells_plot_under_preview", "hut": "none", "steps": [["plot", true]]},
	# The next poses must look like an earlier pose. They check the path of
	# the effect number, not a new look.
	# The batch node is moved and drawn at twice the size, and the camera
	# undoes it. The shader has to take the node's size off the effect number.
	{"name": "hover_with_the_batch_moved", "like": "hover", "moved": true,
		"steps": [["hover", TREE], ["hover", HUT]]},
	{"name": "hit_with_the_batch_moved", "like": "hit_early", "moved": true,
		"steps": [["hit", TREE]], "time": 0.04},
	# 5,000 things off screen flash first, so the tree gets an effect number
	# above 5,000. The four shader numbers of a sprite are only exact to 2,048.
	{"name": "hit_with_a_high_effect_number", "like": "hit_early", "crowd": 5000,
		"steps": [["hit", TREE]], "time": 0.04},
]
## How many pixels of each pose differ from the jam game's picture, measured
## on an Apple M3. A run fails when a pose differs in more. A pose that is
## not listed must match.
const EXPECTED: Dictionary[String, int] = {}

var _update := false
var _save := false
var _quit := false
var _only := ""
var _old_view: SubViewport
var _new_view: SubViewport
var _old_root: Node2D
var _new_root: Node2D
var _old_things: Dictionary[int, Node2D] = {}
var _old_cells: Dictionary[Vector2i, Node2D] = {}
var _old_shots: Array[Node] = []
var _atlas := SpriteAtlas.new()
var _jam := JamEffects.new()
var _style: EffectStyle
var _tree_sprite := SpriteAtlas.NO_SPRITE
var _hut_sprites := PackedInt32Array()
var _cells := JamGrid.cells()
var _rows: BatchRows
var _batch: SpriteBatch
var _effects: SpriteEffects
var _lit: CellHighlights
var _hut_mode := "built"
var _hut_stage := HUT_STAGES - 1
var _hut_blocked := false
var _hovered: Array[int] = []
var _report := Label.new()
var _lines := PackedStringArray()
var _results: Array[Dictionary] = []
var _new_failed := false
var _reference_failed := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		_update = _update or arg == "update=1"
		_save = _save or arg == "save=1" or arg == "update=1"
		_quit = _quit or arg == "quit=1"
		if arg.begins_with("only="):
			_only = arg.trim_prefix("only=")
	if DisplayServer.get_name() == "headless":
		print("EFFECTS needs a window. Run it without --headless.")
		get_tree().quit()
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_style = JamEffects.style()
	_jam.add_to(_atlas)
	_tree_sprite = _atlas.add_file(&"tree", StressArt.STARTER, TREE_REGION)
	for stage in HUT_STAGES:
		var region := Rect2i(Vector2i(stage * HUT_SIZE.x, 0), HUT_SIZE)
		_hut_sprites.append(_atlas.add_file("hut_%d" % stage, HUT_ART, region))
	_atlas.build()
	_build_screen()
	for pose in POSES:
		if _only == "" or String(pose["name"]).contains(_only):
			await _compare(pose)
	var result := PackedStringArray()
	if _new_failed:
		result.append("the toolkit differs from the reference more than expected")
	if _reference_failed:
		result.append("the jam game no longer matches the saved reference pictures")
	var failed := not result.is_empty()
	_lines.append("RESULT: %s" % (". ".join(result) if failed else "as expected"))
	print("EFFECTS ", _lines[_lines.size() - 1])
	if _save:
		await _save_sheets()
	_report.text = "\n".join(_lines)
	print("EFFECTS DONE ", "FAILED" if failed else "OK")
	if _quit:
		get_tree().quit(1 if failed else 0)


func _build_screen() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_old_view = _picture_view()
	_new_view = _picture_view()
	# The jam game's grid sorts its children by height, so this one does too.
	_old_root = Node2D.new()
	_old_root.y_sort_enabled = true
	_old_view.add_child(_old_root)
	_new_root = Node2D.new()
	_new_view.add_child(_new_root)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	_report.text = "Comparing..."
	scroll.add_child(_report)


func _picture_view() -> SubViewport:
	var view := SubViewport.new()
	view.size = PICTURE_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	var camera := Camera2D.new()
	camera.name = "Camera"
	view.add_child(camera)
	return view


func _compare(pose: Dictionary) -> void:
	var pose_name: String = pose["name"]
	var zoom: float = pose.get("zoom", ZOOM)
	var time: float = pose.get("time", 0.0)
	var has_old := ResourceLoader.exists(OLD_TREE)
	for view: SubViewport in [_old_view, _new_view]:
		var camera := view.get_node("Camera") as Camera2D
		camera.zoom = Vector2(zoom, zoom)
		camera.position = Vector2(-20.0, -20.0)
	_stage_new(pose)
	if pose.get("moved", false):
		var camera := _new_view.get_node("Camera") as Camera2D
		_batch.position = MOVED_TO
		_batch.scale = Vector2(MOVED_SCALE, MOVED_SCALE)
		camera.zoom = Vector2(zoom, zoom) / MOVED_SCALE
		camera.position = MOVED_TO + Vector2(-20.0, -20.0) * MOVED_SCALE
	for number in int(pose.get("crowd", 0)):
		# Far above the picture, where the batch leaves them out.
		_rows.add_thing(CROWD + number, Vector2i(number % 50 - 25, -30), _tree_sprite)
		_effects.flash(SpriteEffects.thing(CROWD + number))
	if has_old:
		_stage_old(pose)
	for step: Array in pose["steps"]:
		_act_new(step)
		if has_old:
			await _act_old(step)
	_effects.advance(time)
	if has_old:
		_freeze_old(time)
	for frame in 3:
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var new_picture := _new_view.get_texture().get_image()
	var reference_path := PICTURES + "%s_reference.png" % pose.get("like", pose_name)
	var notes := PackedStringArray()
	if pose.has("crowd"):
		notes.append("the tree reads line %d" % _effects.line_of(SpriteEffects.thing(TREE)))
	if has_old:
		var old_picture := _old_view.get_texture().get_image()
		if _update and not pose.has("like"):
			old_picture.save_png(reference_path)
			notes.append("reference written")
		var drift := _differences(old_picture, _load_picture(reference_path))
		notes.append("jam game against reference: %s" % _count_text(drift))
		_reference_failed = _reference_failed or drift != 0
	var reference := _load_picture(reference_path)
	var differ := _differences(new_picture, reference)
	var slight := _differences(new_picture, reference, 0) - differ
	if slight > 0:
		notes.append("%d more are a rounding step apart" % slight)
	var expected: int = EXPECTED.get(pose_name, 0)
	var verdict := "OK"
	if differ < 0 or differ > expected:
		verdict = "MORE THAN EXPECTED"
		_new_failed = true
	var line := "%s: toolkit %s from the reference, expected at most %d. %s. (%s)" % [
		pose_name, _count_text(differ), expected, verdict, ", ".join(notes),
	]
	_lines.append(line)
	print("EFFECTS ", line)
	_results.append({"name": pose_name, "old": reference, "new": new_picture, "differ": differ})
	if _save and reference != null:
		var side := Image.create_empty(PICTURE_SIZE.x * 2, PICTURE_SIZE.y, false, Image.FORMAT_RGBA8)
		var whole := Rect2i(Vector2i.ZERO, PICTURE_SIZE)
		reference.convert(Image.FORMAT_RGBA8)
		new_picture.convert(Image.FORMAT_RGBA8)
		side.blit_rect(reference, whole, Vector2i.ZERO)
		side.blit_rect(new_picture, whole, Vector2i(PICTURE_SIZE.x, 0))
		side.save_png(PICTURES + "%s_side.png" % pose_name)


## Builds the toolkit's side of a pose: a fresh batch with the three things.
func _stage_new(pose: Dictionary) -> void:
	if _effects != null:
		_effects.close()
	for child in _new_root.get_children():
		child.free()
	_rows = JamGrid.rows(_atlas, Rect2(-2000.0, -2000.0, 4000.0, 4000.0))
	_batch = SpriteBatch.new()
	_batch.setup(_rows, MeepleLook.SHADER)
	_new_root.add_child(_batch)
	_effects = SpriteEffects.new(_rows, _style)
	_effects.dress(_batch)
	_lit = _jam.cell_highlights(_rows)
	_rows.add_thing(TREE, TREE_CELL, _tree_sprite, TREE_OFFSET)
	_rows.add_thing(FRONT, FRONT_CELL, _tree_sprite, TREE_OFFSET)
	if pose.get("neighbours", false):
		_rows.add_thing(LEFT, TREE_CELL + Vector2i.LEFT, _tree_sprite, TREE_OFFSET)
		_rows.add_thing(RIGHT, TREE_CELL + Vector2i.RIGHT, _tree_sprite, TREE_OFFSET)
	_hut_mode = pose.get("hut", "built")
	_hut_stage = pose.get("stage", HUT_STAGES - 1)
	_hut_blocked = false
	_hovered.clear()
	if _hut_mode == "none":
		return
	var footprint: Array[Vector2i] = [HUT_CELL, HUT_CELL + Vector2i(1, 0)]
	var shown := _hut_sprites[maxi(_hut_stage, 0)]
	var tint := Color.WHITE if _hut_stage >= 0 else Color(1.0, 1.0, 1.0, 0.0)
	_rows.add_thing(HUT, HUT_CELL, shown, HUT_OFFSET, tint, footprint)
	_dress_new_hut()


## Shows the hut of the toolkit's side as a preview or as a site.
func _dress_new_hut() -> void:
	var target := SpriteEffects.thing(HUT)
	if _hut_mode == "preview":
		_effects.ghost(target, true, _hut_blocked)
	elif _hut_mode == "site" and _hut_stage + 1 < HUT_STAGES:
		_effects.ghost_under(target, _hut_sprites[_hut_stage + 1], _hut_blocked)


func _act_new(step: Array) -> void:
	var what: String = step[0]
	var id: int = step[1] if step[1] is int else 0
	var target := SpriteEffects.thing(id)
	match what:
		"wait":
			_effects.advance(step[1])
		"grow_in":
			_effects.grow_in(target)
		"hit":
			_jam.hit(_effects, target)
		"last_hit":
			_jam.last_hit(_effects, target)
		"reject":
			_effects.reject(target)
		"flash":
			_effects.flash(target)
		"pop":
			_effects.pop(target)
		"select":
			_effects.select(target, true, step[2])
		"hover":
			_effects.hover(target, true)
			_hovered.append(id)
			var lit: Array[Vector2i] = []
			for other in _hovered:
				lit.append_array(_rows.thing_cells(other))
			_lit.show(&"hover", lit, _style.cell_hover_colour, JamEffects.RANK_HOVER)
		"block":
			_hut_blocked = true
			_dress_new_hut()
		"sparks":
			_jam.sparks(_effects, id)
		"cloud":
			_jam.cloud(_effects, id, step[2])
		"remove":
			_effects.forget(target)
			_rows.remove_thing(id)
		"cursor":
			var corners := JamEffects.cell_corners(JamGrid.ART_SCALE)
			var radius := JamEffects.CURSOR_RADIUS * JamGrid.ART_SCALE
			var round_mouse := CellHighlights.cells_in_circle(_cells, corners, step[1], radius)
			_lit.show(&"cursor", round_mouse, _style.cell_cursor_colour, JamEffects.RANK_CURSOR)
		"plot":
			_lit.show(&"area", _plot_cells(), _style.cell_area_colour, JamEffects.RANK_AREA)
			if step[1]:
				_lit.show(
					&"area_hover", _plot_hover_cells(), _style.cell_area_hover_colour,
					JamEffects.RANK_AREA_HOVER
				)


## Builds the jam game's side of a pose from its own scenes.
func _stage_old(pose: Dictionary) -> void:
	for child in _old_root.get_children():
		child.free()
	_old_things.clear()
	_old_cells.clear()
	_old_shots.clear()
	var cell_scene := load(OLD_CELL) as PackedScene
	for row in range(-STAGE.y, STAGE.y + 1):
		for column in range(-STAGE.x, STAGE.x + 1):
			var cell := cell_scene.instantiate() as Node2D
			cell.position = _cells.position_of(Vector2i(column, row))
			_old_root.add_child(cell)
			_old_cells[Vector2i(column, row)] = cell
	_old_things[TREE] = _old_thing(OLD_TREE, [TREE_CELL])
	_old_things[FRONT] = _old_thing(OLD_TREE, [FRONT_CELL])
	if pose.get("neighbours", false):
		_old_things[LEFT] = _old_thing(OLD_TREE, [TREE_CELL + Vector2i.LEFT])
		_old_things[RIGHT] = _old_thing(OLD_TREE, [TREE_CELL + Vector2i.RIGHT])
	var hut: String = pose.get("hut", "built")
	if hut == "none":
		return
	var node := _old_thing(OLD_HUT, [HUT_CELL, HUT_CELL + Vector2i(1, 0)])
	_old_things[HUT] = node
	if hut == "preview":
		node.call("show_as_preview")
	else:
		node.call("_set_stage", int(pose.get("stage", HUT_STAGES - 1)))


func _old_thing(scene_path: String, cells: Array[Vector2i]) -> Node2D:
	var node := (load(scene_path) as PackedScene).instantiate() as Node2D
	node.position = _cells.position_of(cells[0])
	_old_root.add_child(node)
	var stood_on: Array[Node2D] = []
	for cell in cells:
		stood_on.append(_old_cells[cell])
	# The jam script wants a typed list of its own cell class.
	node.set("cells", Array(stood_on, TYPE_OBJECT, &"Sprite2D", load(OLD_CELL_SCRIPT)))
	return node


func _act_old(step: Array) -> void:
	var what: String = step[0]
	var node: Node2D = _old_things.get(step[1]) if step[1] is int else null
	match what:
		"wait":
			_freeze_old(step[1])
		"grow_in":
			node.call("grow_in")
		"hit":
			node.call("_react")
		"last_hit":
			node.call("_shatter")
		"reject":
			node.call("reject")
		"flash":
			node.call("flash")
		"pop":
			node.call("_pop")
		"select":
			node.call("set_selected", true, step[2])
		"hover":
			node.call("_set_hovered", true)
		"block":
			if node.get("_blueprint") == null:
				node.call("set_preview_blocked", true)
			else:
				node.call("_set_missing", Dictionary({"wood": 1}, TYPE_STRING, &"", null,
					TYPE_INT, &"", null))
		"sparks":
			node.call("spawn_effect", load(OLD_SPARKS), 0)
			_old_shots.append(_old_root.get_child(_old_root.get_child_count() - 1))
		"cloud":
			node.set("effect_offset", step[2])
			node.call("spawn_effect", load(OLD_CLOUD), 1)
			_old_shots.append(_old_root.get_child(_old_root.get_child_count() - 1))
		"remove":
			node.free()
			_old_things.erase(step[1])
		"cursor":
			await _old_cursor(step[1])
		"plot":
			var hovered := _plot_hover_cells() if step[1] else ([] as Array[Vector2i])
			for cell in _plot_cells():
				if hovered.has(cell):
					_old_cells[cell].call("highlight", 1.0, Color(1.0, 1.0, 1.0))
				else:
					_old_cells[cell].call("highlight", 0.7, Color(1.0, 0.95, 0.6))


## Lights the cells round a point the way the jam game's mouse does: with a
## circle area, and the cells whose own area it overlaps.
func _old_cursor(point: Vector2) -> void:
	var cursor := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = JamEffects.CURSOR_RADIUS * JamGrid.ART_SCALE
	shape.shape = circle
	cursor.add_child(shape)
	cursor.position = point
	_old_root.add_child(cursor)
	for frame in 3:
		await get_tree().physics_frame
	for area in cursor.get_overlapping_areas():
		var cell := area.get_parent()
		if _old_cells.values().has(cell):
			cell.call("highlight", 0.5)
	cursor.free()


## Stops the jam game's tweens and moves them on by [param time] seconds.
## A one-shot of the jam game is not played: it is stopped and put on the
## picture it shows [param time] seconds after it began, with the same sum
## as [method EffectShots.advance_to]. Its scene, its pictures, its place and
## its rate are the jam game's.
func _freeze_old(time: float) -> void:
	for node: Node2D in _old_things.values():
		var tweens: Dictionary = node.get("_tweens")
		for tween: Tween in tweens.values():
			if tween.is_valid():
				tween.pause()
				tween.custom_step(time)
	for shot in _old_shots:
		var sprite := shot as AnimatedSprite2D
		sprite.pause()
		var rate := sprite.sprite_frames.get_animation_speed(sprite.animation)
		var frame := floori(time * rate + 0.000001)
		if frame >= sprite.sprite_frames.get_frame_count(sprite.animation):
			sprite.visible = false
		else:
			sprite.frame = frame


func _plot_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in PLOT_SIZE.y:
		for column in PLOT_SIZE.x:
			cells.append(PLOT_ORIGIN + Vector2i(column, row))
	return cells


func _plot_hover_cells() -> Array[Vector2i]:
	return [PLOT_ORIGIN + Vector2i(1, 1), PLOT_ORIGIN + Vector2i(2, 1)]


func _count_text(differ: int) -> String:
	return "pictures cannot be compared" if differ < 0 else "%d pixels differ" % differ


## Returns how many pixels of two pictures differ by more than
## [param tolerance] in a channel, or -1 when they cannot be compared.
func _differences(a: Image, b: Image, tolerance: int = TOLERANCE) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var bytes_a := a.get_data()
	var bytes_b := b.get_data()
	if bytes_a == bytes_b:
		return 0
	var count := 0
	for at in range(0, bytes_a.size(), 4):
		if (
			absi(bytes_a[at] - bytes_b[at]) > tolerance
			or absi(bytes_a[at + 1] - bytes_b[at + 1]) > tolerance
			or absi(bytes_a[at + 2] - bytes_b[at + 2]) > tolerance
		):
			count += 1
	return count


func _load_picture(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var picture := Image.new()
	if picture.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return picture


## Saves sheets with a few poses each: the jam game on the left, the toolkit
## on the right, and the name of the pose above them.
func _save_sheets() -> void:
	_report.visible = false
	var sheet := GridContainer.new()
	sheet.columns = 2
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)
	var number := 1
	for first in range(0, _results.size(), POSES_PER_SHEET):
		for child in sheet.get_children():
			child.free()
		for result: Dictionary in _results.slice(first, first + POSES_PER_SHEET):
			sheet.add_child(_sheet_entry(result))
		for frame in 3:
			await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(PICTURES + "sheet_%d.png" % number)
		number += 1
	sheet.free()
	_report.visible = true


func _sheet_entry(result: Dictionary) -> Control:
	var entry := VBoxContainer.new()
	entry.custom_minimum_size = Vector2(960.0, 360.0)
	var title := Label.new()
	title.text = "  %s:  jam game left, toolkit right.  %s" % [
		result["name"], _count_text(result["differ"]),
	]
	title.add_theme_font_size_override(&"font_size", 22)
	entry.add_child(title)
	var pair := HBoxContainer.new()
	pair.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entry.add_child(pair)
	for key: String in ["old", "new"]:
		var shown := TextureRect.new()
		var picture: Image = result[key]
		if picture != null:
			shown.texture = ImageTexture.create_from_image(picture)
		shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pair.add_child(shown)
	return entry
