extends Node2D
## Demo for issue #62: every effect of the toolkit on a tree, a building and
## a meeple.
##
## Open [code]effects_demo.tscn[/code] and press F6. The keys are listed on
## screen. Every effect key plays its effect on all the actors at once: two
## trees, a finished hut, a building site, a standing meeple and a walking one.
## Move the mouse over an actor for the hover glow.
##
## The effects run on game time. Space pauses the game and 1 to 4 set the
## game speed, through the Game service.
##
## From a terminal, [code]-- shot=/path.png keys=H,O at=0.05[/code] presses
## those keys, waits that many seconds of game time, saves a picture and
## closes the scene.

## The game speeds of the jam game, on the keys 1 to 4.
const SPEEDS: Array[float] = [1.0, 1.5, 2.0, 3.0]
## The camera zoom: 16 screen pixels for one art pixel.
const ZOOM := 1.6
## The hut sheet of the jam game: five build stages of 15 by 14 art pixels.
const HUT_ART := "res://assets/Art/Buildings/House_buildstates.png"
const HUT_SIZE := Vector2i(15, 14)
const HUT_STAGES := 5
const HUT_OFFSET := Vector2(3.5, -3.0)
## The jam tree: its part of the sheet, and its offset.
const TREE_REGION := Rect2i(37, 2, 6, 8)
const TREE_OFFSET := Vector2(0.0, -3.0)
## The numbers of the things in the batch, and where each one stands.
const TREE := 1
const FRONT_TREE := 2
const HUT := 3
const SITE := 4
const THING_CELLS: Dictionary[int, Vector2i] = {
	TREE: Vector2i(-6, 0), FRONT_TREE: Vector2i(-7, 1), HUT: Vector2i(-2, 0), SITE: Vector2i(3, 0),
}
## The two meeples: one stands, one walks between two points.
const STANDING := 0
const WALKING := 1
const STAND_SPOT := Vector2(-10.0, 55.0)
const WALK_FROM := Vector2(80.0, 55.0)
const WALK_TO := Vector2(330.0, 55.0)
const WALK_SPEED := 60.0
## The plot area that the placing mode shows.
const PLOT_ORIGIN := Vector2i(-6, 3)
const PLOT_SIZE := Vector2i(5, 3)
const HELP := """Every key plays its effect on the trees, the huts and the meeples.
H hit (squash, flash, wobble)     F flash     R refused (red flash, shake)
Q squash     W wobble     P pop     G grow in     L last hit (stays white)
O selected outline     Y paused outline (yellow)     B blueprint ghost     N ghost blocked
K sparks     C dust cloud     [ ] building site stage     M placing mode (cells light up)
Mouse over an actor: hover glow and lit cells.     Z glow on every actor
Space pause     1 2 3 4 game speed"""

var _jam := JamEffects.new()
var _look := MeepleLook.new()
var _style: EffectStyle
var _cells := JamGrid.cells()
var _rows: BatchRows
var _batch: SpriteBatch
var _effects: SpriteEffects
var _lit: CellHighlights
var _tree_sprite := SpriteAtlas.NO_SPRITE
var _hut_sprites := PackedInt32Array()
var _spots := PackedVector2Array([STAND_SPOT, WALK_FROM])
var _walk_direction := 1.0
var _site_stage := 1
var _selected := false
var _paused_outline := false
var _ghost := false
var _blocked := false
var _placing := false
var _glow_all := false
var _hovered := -1
var _label := Label.new()
var _shot := ""
var _shot_keys := PackedStringArray()
var _shot_at := 0.0


func _ready() -> void:
	_read_arguments()
	_style = JamEffects.style()
	var atlas := SpriteAtlas.new()
	_jam.add_to(atlas)
	_look.add_to(atlas)
	_tree_sprite = atlas.add_file(&"tree", StressArt.STARTER, TREE_REGION)
	for stage in HUT_STAGES:
		var region := Rect2i(Vector2i(stage * HUT_SIZE.x, 0), HUT_SIZE)
		_hut_sprites.append(atlas.add_file("hut_%d" % stage, HUT_ART, region))
	atlas.build()
	_rows = JamGrid.rows(atlas, Rect2(-2000.0, -2000.0, 4000.0, 4000.0))
	_look.shape(_rows)
	_batch = SpriteBatch.new()
	_batch.setup(_rows, MeepleLook.SHADER)
	_look.dress(_batch)
	add_child(_batch)
	_effects = SpriteEffects.new(_rows, _style)
	_effects.dress(_batch)
	_lit = _jam.cell_highlights(_rows)
	_add_actors()
	var camera := Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	camera.position = Vector2(-60.0, 40.0)
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label.position = Vector2(16.0, 12.0)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)
	if _shot != "":
		_take_shot.call_deferred()


func _exit_tree() -> void:
	_effects.close()
	Game.end_session()


func _process(delta: float) -> void:
	# Effects run on game time: the Game service says how fast, and whether at all.
	_effects.advance(delta, Game.speed, Game.paused)
	_batch.clock_frozen = Game.paused
	if not Game.paused:
		_walk(delta * Game.speed)
	if _shot == "":
		_hover()
		_show_placing()
	_label.text = "%s\n\nSpeed x%s%s     Effect clock %.2f s     Sprites with an effect: %d" % [
		HELP, Game.speed, "   PAUSED" if Game.paused else "", _effects.clock(),
		_effects.active_count(),
	]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_press(OS.get_keycode_string(key.physical_keycode))


func _read_arguments() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			_shot = arg.trim_prefix("shot=")
		elif arg.begins_with("keys="):
			_shot_keys = arg.trim_prefix("keys=").split(",", false)
		elif arg.begins_with("at="):
			_shot_at = float(arg.trim_prefix("at="))


func _add_actors() -> void:
	_rows.add_thing(TREE, THING_CELLS[TREE], _tree_sprite, TREE_OFFSET)
	_rows.add_thing(FRONT_TREE, THING_CELLS[FRONT_TREE], _tree_sprite, TREE_OFFSET)
	for id: int in [HUT, SITE]:
		var cell := THING_CELLS[id]
		var footprint: Array[Vector2i] = [cell, cell + Vector2i(1, 0)]
		_rows.add_thing(id, cell, _hut_sprites[HUT_STAGES - 1], HUT_OFFSET, Color.WHITE, footprint)
	_show_site()
	_rows.resize_movers(2)
	_rows.place_mover(
		STANDING, _spots[STANDING], MeepleLook.shirt_colour(0.58),
		_look.numbers(MeepleLook.EMPTY_HANDED, 0.0, false)
	)
	_rows.place_mover(
		WALKING, _spots[WALKING], MeepleLook.shirt_colour(0.05),
		_look.numbers(MeepleLook.head_frame(&"wood", 1), 7.0, true)
	)


## Every actor an effect key plays on, as effect targets.
func _targets() -> Array[int]:
	var targets: Array[int] = []
	for id: int in THING_CELLS:
		if _rows.has_thing(id):
			targets.append(SpriteEffects.thing(id))
	targets.append(SpriteEffects.mover(STANDING))
	targets.append(SpriteEffects.mover(WALKING))
	return targets


func _press(key: String) -> void:
	match key:
		"Space":
			Game.paused = not Game.paused
		"1", "2", "3", "4":
			Game.speed = SPEEDS[int(key) - 1]
		"O":
			_selected = not _selected
			_paused_outline = false
		"Y":
			_paused_outline = not _paused_outline
			_selected = false
		"B":
			_ghost = not _ghost
		"N":
			_blocked = not _blocked
			_show_site()
		"BracketLeft":
			_site_stage = maxi(_site_stage - 1, -1)
			_show_site()
		"BracketRight":
			_site_stage = mini(_site_stage + 1, HUT_STAGES - 1)
			_show_site()
		"M":
			_placing = not _placing
		"Z":
			_glow_all = not _glow_all
			_hovered = -1
		"K":
			for id: int in [TREE, FRONT_TREE]:
				_jam.sparks(_effects, id)
		"C":
			_jam.cloud(_effects, HUT)
			_jam.cloud(_effects, SITE, Vector2(0.0, 10.0))
	for target in _targets():
		_play(key, target)


## Plays the effect of one key on one actor. This is the whole of what a
## game script writes for an effect: one call, the same for every sprite.
func _play(key: String, target: int) -> void:
	match key:
		"H":
			_jam.hit(_effects, target)
		"L":
			_jam.last_hit(_effects, target)
		"F":
			_effects.flash(target)
		"R":
			_effects.reject(target)
		"Q":
			_effects.squash(target)
		"W":
			_effects.wobble(target)
		"P":
			_effects.pop(target)
		"G":
			_effects.grow_in(target)
		"O", "Y":
			var tint := JamEffects.PAUSED_OUTLINE if _paused_outline else Color.WHITE
			_effects.select(target, _selected or _paused_outline, tint)
		"B", "N":
			if target != SpriteEffects.thing(SITE):
				_effects.ghost(target, _ghost, _blocked)
		"Z":
			_effects.hover(target, _glow_all)


## Shows the building site at its stage: the built part, and the next stage
## as a ghost behind it.
func _show_site() -> void:
	var tint := Color.WHITE if _site_stage >= 0 else Color(1.0, 1.0, 1.0, 0.0)
	_rows.change_thing(SITE, _hut_sprites[maxi(_site_stage, 0)], HUT_OFFSET, tint)
	var next := SpriteAtlas.NO_SPRITE
	if _site_stage + 1 < HUT_STAGES:
		next = _hut_sprites[_site_stage + 1]
	_effects.ghost_under(SpriteEffects.thing(SITE), next, _blocked)


func _walk(seconds: float) -> void:
	var spot := _spots[WALKING]
	spot.x += _walk_direction * WALK_SPEED * seconds
	if spot.x > WALK_TO.x or spot.x < WALK_FROM.x:
		_walk_direction = -_walk_direction
		spot.x = clampf(spot.x, WALK_FROM.x, WALK_TO.x)
	_spots[WALKING] = spot
	_rows.move_movers(_spots)


## The actor under the mouse glows, and the cells it stands on light up.
func _hover() -> void:
	if _glow_all:
		return
	var mouse := _batch.to_world(get_viewport().get_mouse_position())
	var found := -1
	var thing := _rows.pick(mouse)
	if thing != BatchRows.NO_THING:
		found = SpriteEffects.thing(thing)
	var box := Rect2(Vector2.ZERO, MeepleLook.BOX * _rows.pixel_scale)
	for index in _spots.size():
		box.position = _spots[index] + MeepleLook.BOX_OFFSET * _rows.pixel_scale - box.size * 0.5
		if box.has_point(mouse):
			found = SpriteEffects.mover(index)
	if found == _hovered:
		return
	if _hovered != -1:
		_effects.hover(_hovered, false)
	_hovered = found
	if found != -1:
		_effects.hover(found, true)
	var under: Array[Vector2i] = []
	if thing != BatchRows.NO_THING and found == SpriteEffects.thing(thing):
		under = _rows.thing_cells(thing)
	_lit.show(&"hover", under, _style.cell_hover_colour, JamEffects.RANK_HOVER)


## In placing mode the cells round the mouse light up grey, and a plot area
## shows in pale yellow with white under the mouse.
func _show_placing() -> void:
	if not _placing:
		_lit.clear(&"cursor")
		_lit.clear(&"area")
		_lit.clear(&"area_hover")
		return
	var mouse := _batch.to_world(get_viewport().get_mouse_position())
	var corners := JamEffects.cell_corners(_rows.pixel_scale)
	var radius := JamEffects.CURSOR_RADIUS * _rows.pixel_scale
	var round_mouse := CellHighlights.cells_in_circle(_cells, corners, mouse, radius)
	_lit.show(&"cursor", round_mouse, _style.cell_cursor_colour, JamEffects.RANK_CURSOR)
	var plot: Array[Vector2i] = []
	for row in PLOT_SIZE.y:
		for column in PLOT_SIZE.x:
			plot.append(PLOT_ORIGIN + Vector2i(column, row))
	_lit.show(&"area", plot, _style.cell_area_colour, JamEffects.RANK_AREA)
	var under: Array[Vector2i] = []
	var mouse_cell := _cells.cell_at(mouse)
	if plot.has(mouse_cell):
		under.append(mouse_cell)
	_lit.show(&"area_hover", under, _style.cell_area_hover_colour, JamEffects.RANK_AREA_HOVER)


func _take_shot() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	set_process(false)
	_label.text = "%s\n\nKeys pressed: %s     Picture taken %s s later" % [
		HELP, ", ".join(_shot_keys), _shot_at,
	]
	for frame in 3:
		await get_tree().process_frame
	for key in _shot_keys:
		_press(key)
	_effects.advance(_shot_at)
	_walk(_shot_at)
	_batch.clock_frozen = true
	for frame in 3:
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(_shot)
	print("DEMO_SHOT ", _shot)
	get_tree().quit()
