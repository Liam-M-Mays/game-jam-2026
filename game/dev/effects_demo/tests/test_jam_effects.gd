extends GameTest
## Checks the jam game's effect numbers, one test per "Must keep" line of
## issue #62 that has a number. Each test runs the real toolkit with the
## saved numbers and asks it what the sprite is doing.

var _rows: BatchRows
var _effects: SpriteEffects
var _jam := JamEffects.new()
var _style: EffectStyle
var _tree: int
var _tree_sprite: int


func before_each() -> void:
	var atlas := SpriteAtlas.new()
	_jam.add_to(atlas)
	_tree_sprite = atlas.add_file(&"tree", StressArt.STARTER, Rect2i(37, 2, 6, 8))
	atlas.build()
	_rows = JamGrid.rows(atlas, Rect2(-2000.0, -2000.0, 4000.0, 4000.0))
	_rows.add_thing(1, Vector2i(2, 3), _tree_sprite, Vector2(0.0, -3.0))
	_style = JamEffects.style()
	_effects = SpriteEffects.new(_rows, _style)
	_tree = SpriteEffects.thing(1)


func after_each() -> void:
	_effects.close()


func test_a_respawned_resource_grows_in_from_a_sliver_in_half_a_second() -> void:
	_effects.grow_in(_tree)
	check_eq(_scale(), Vector2(0.4, 0.05), "it starts 0.4 wide and 0.05 tall")
	_effects.advance(0.25)
	var half := EffectCurves.back_out(0.5)
	check_near(_scale().x, 0.4 + 0.6 * half, 0.000001, "springy ease, half way")
	check_near(_scale().y, 0.05 + 0.95 * half, 0.000001)
	check(_scale().y > 1.0, "half way it is already taller than full size: the overshoot")
	_effects.advance(0.249)
	check(_effects.has_effect(_tree), "still growing just before 0.5 seconds")
	_effects.advance(0.001)
	check(not _effects.has_effect(_tree), "full size at 0.5 seconds")
	check_eq(_scale(), Vector2.ONE)


func test_a_hit_squashes_to_115_by_85_percent_and_springs_back_in_a_fifth_second() -> void:
	_jam.hit(_effects, _tree)
	check_eq(_scale(), Vector2(1.15, 0.85))
	_effects.advance(0.1)
	check_near(_scale().x, 1.15 - 0.15 * EffectCurves.back_out(0.5), 0.000001)
	check_near(_scale().y, 0.85 + 0.15 * EffectCurves.back_out(0.5), 0.000001)
	check(_scale().x < 1.0 and _scale().y > 1.0, "a small overshoot past full size")
	_effects.advance(0.1)
	check_eq(_scale(), Vector2.ONE, "back after 0.2 seconds")


func test_a_hit_flashes_white_and_fades_in_012_seconds() -> void:
	_jam.hit(_effects, _tree)
	check_eq(_effects.pose(_tree)["flash"], 1.0)
	check_eq(_effects.pose(_tree)["flash_colour"], Color.WHITE)
	_effects.advance(0.06)
	check_near(_effects.pose(_tree)["flash"], 0.5, 0.000001, "a straight fade")
	_effects.advance(0.06)
	check_near(_effects.pose(_tree)["flash"], 0.0, 0.000001)


func test_a_hit_wobbles_3_degrees_each_way_in_a_quarter_second() -> void:
	_jam.hit(_effects, _tree)
	var want := {0.0625: 3.0, 0.125: 0.0, 0.1875: -3.0}
	var at := 0.0
	for moment: float in want:
		_effects.advance(moment - at)
		at = moment
		check_near(_effects.pose(_tree)["degrees"], want[moment], 0.000001, "at %s s" % moment)
	_effects.advance(0.0625)
	check(not _effects.has_effect(_tree), "the whole hit is over after 0.25 seconds")


func test_the_last_hit_squashes_and_stays_white_for_006_seconds() -> void:
	_jam.last_hit(_effects, _tree)
	check_eq(_scale(), Vector2(1.15, 0.85))
	_effects.advance(0.059)
	check_eq(_effects.pose(_tree)["flash"], 1.0, "still solid white just before the break")
	check_eq(JamEffects.BREAK_HOLD, 0.06)


func test_a_refused_click_flashes_red_for_012_seconds() -> void:
	_effects.reject(_tree)
	check_eq(_effects.pose(_tree)["flash_colour"], Color(1.0, 0.15, 0.15))
	check_eq(_effects.pose(_tree)["flash"], 1.0)
	_effects.advance(0.03)
	check_near(_effects.pose(_tree)["flash"], 0.75, 0.000001)
	_effects.advance(0.09)
	check_near(_effects.pose(_tree)["flash"], 0.0, 0.000001)


func test_a_refused_click_shakes_in_five_steps_of_006_seconds() -> void:
	_effects.reject(_tree)
	check_eq(_effects.pose(_tree)["shift"], 0.0, "it starts from rest")
	var want: Array[float] = [1.5, -1.5, 0.75, -0.75, 0.0]
	for step in 5:
		_effects.advance(0.06)
		check_near(_effects.pose(_tree)["shift"], want[step], 0.000001, "after step %d" % (step + 1))
	check(not _effects.has_effect(_tree), "over after 0.3 seconds")


func test_a_delivery_pops_the_building_to_105_percent() -> void:
	_effects.pop(_tree)
	_effects.advance(0.025)
	check_near(_scale().x, 1.0 + 0.05 * sin(PI * 0.25), 0.000001, "sine ease on the way up")
	_effects.advance(0.025)
	check_near(_scale().x, 1.05, 0.000001, "the top after 0.05 seconds")
	check_near(_scale().y, 1.05, 0.000001)
	_effects.advance(0.065)
	check_near(_scale().x, 1.05 - 0.05 * sin(PI * 0.25), 0.000001, "sine ease on the way back")
	_effects.advance(0.065)
	check(not _effects.has_effect(_tree), "back after another 0.13 seconds")


func test_effects_run_in_the_named_slots_of_the_jam_game() -> void:
	# flash, shake, squash (also used by grow in), wobble, pop.
	check_eq(EffectState.SLOTS, 5)
	_effects.reject(_tree)
	_jam.hit(_effects, _tree)
	_effects.pop(_tree)
	_effects.advance(0.03)
	var pose := _effects.pose(_tree)
	check_eq(pose["flash_colour"], Color.WHITE, "the hit's flash took the place of the red one")
	check_near(pose["shift"], 0.75, 0.000001, "the shake plays on")
	check(pose["degrees"] > 0.0, "next to the wobble")
	check(pose["scale"] != Vector2.ONE, "and the squash and the pop")
	_effects.grow_in(_tree)
	var grow := Vector2(0.4, 0.05) * EffectCurves.pop_scale(0.03, 0.05, 0.05, 0.13)
	check_near(_scale().x, grow.x, 0.000001, "grow in took the squash slot, the pop plays on")
	check_near(_scale().y, grow.y, 0.000001)


func test_the_selected_outline_is_a_thin_solid_white_line() -> void:
	check_eq(_style.select_colour, Color(1, 1, 1, 1))
	check_eq(_style.select_width, 2.0)
	check_eq(_style.select_glow_size, 0.0)
	check_eq(_style.select_glow_strength, 0.6)
	check_eq(_style.select_pulse_speed, 0.0)
	check_eq(_style.select_pulse_amount, 0.5)
	_effects.select(_tree, true)
	check_eq(_effects.table().read(_effects.line_of(_tree), 0), Vector4(2.0, 1.0, 1.0, 1.0))


func test_the_hover_outline_is_a_soft_white_glow_with_no_line() -> void:
	check_eq(_style.hover_colour, Color(1, 1, 1, 1))
	check_eq(_style.hover_width, 0.0)
	check_eq(_style.hover_glow_size, 8.0)
	check_eq(_style.hover_glow_strength, 0.5)
	check_eq(_style.hover_pulse_speed, 0.0)
	check_eq(_style.hover_pulse_amount, 0.5)


func test_a_selected_thing_can_be_hovered_too_and_tinted() -> void:
	_effects.select(_tree, true, JamEffects.PAUSED_OUTLINE)
	_effects.hover(_tree, true)
	var line := _effects.table().read(_effects.line_of(_tree), 0)
	check_eq(line.x, 3.0, "selected and hovered at once")
	check_near(line.y, 1.0, 0.000001)
	check_near(line.z, 0.85, 0.000001)
	check_near(line.w, 0.1, 0.000001)


func test_the_ghost_numbers_are_the_jam_games() -> void:
	check_eq(_style.ghost_colour, Color(0.35, 0.65, 1.0))
	check_eq(_style.ghost_blocked_colour, Color(1.0, 0.35, 0.35))
	check_eq(_style.ghost_opacity, 0.5, "the placement ghost")
	check_eq(_style.ghost_under_opacity, 0.32, "the ghost of the next stage")
	check_eq(_style.ghost_dark, 0.7)
	check_eq(_style.ghost_light, 1.3)
	_effects.ghost(_tree, true, true)
	var ghost := _effects.table().read(_effects.line_of(_tree), 1)
	check_near(ghost.x, 1.0, 0.000001, "a blocked ghost is red")
	check_near(ghost.y, 0.35, 0.000001)
	check_near(ghost.z, 0.35, 0.000001)
	check_near(ghost.w, 0.5, 0.000001)


func test_the_cell_colours_are_the_jam_games() -> void:
	check_eq(_style.cell_hover_colour, Color(0.4, 0.4, 0.4, 0.5), "under a hovered thing")
	check_eq(_style.cell_cursor_colour, Color(0.4, 0.4, 0.4, 0.5), "round the mouse while placing")
	check_eq(_style.cell_area_colour, Color(1.0, 0.95, 0.6, 0.7), "barn plot cells")
	check_eq(_style.cell_area_hover_colour, Color(1.0, 1.0, 1.0, 1.0), "under the preview")
	check_eq(JamEffects.CURSOR_RADIUS * JamGrid.ART_SCALE, 200.0, "the circle round the mouse")


func test_lit_cells_show_the_jam_cell_picture_and_the_plot_wins_over_hover() -> void:
	var cells := _jam.cell_highlights(_rows)
	var plot: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 3)]
	cells.show(&"hover", _rows.thing_cells(1), _style.cell_hover_colour, JamEffects.RANK_HOVER)
	check_eq(cells.colour_of(Vector2i(2, 3)), Color(0.4, 0.4, 0.4, 0.5))
	cells.show(&"area", plot, _style.cell_area_colour, JamEffects.RANK_AREA)
	cells.show(
		&"area_hover", [Vector2i(3, 3)], _style.cell_area_hover_colour, JamEffects.RANK_AREA_HOVER
	)
	check_eq(cells.colour_of(Vector2i(2, 3)), Color(1.0, 0.95, 0.6, 0.7))
	check_eq(cells.colour_of(Vector2i(3, 3)), Color(1.0, 1.0, 1.0, 1.0))
	var buffer := PackedFloat32Array()
	_rows.assemble(Rect2(-1e6, -1e6, 2e6, 2e6), buffer)
	check_eq(int(buffer[12]), _jam.cell_sprite, "the cell picture is drawn first, under the tree")
	check_eq(Vector2(buffer[0], buffer[5]), Vector2(130.0, 80.0), "13 by 8 art pixels")
	var at := JamGrid.cells().position_of(Vector2i(2, 3))
	check_eq(Vector2(buffer[3], buffer[7]), at + Vector2(-5.0, 0.0), "half an art pixel left")


func test_the_spark_burst_is_three_pictures_at_sixteen_a_second() -> void:
	check_eq(_jam.spark_sprites.size(), 3)
	for sprite in _jam.spark_sprites:
		check_eq(_rows.atlas.size_of(sprite), Vector2i(13, 13))
	var shot := _jam.sparks(_effects, 1)
	_rows.remove_thing(1)
	check_eq(_decor_middle(), JamGrid.cells().position_of(Vector2i(2, 3)) + Vector2(0.0, -30.0))
	_effects.advance(0.0624)
	check_eq(_effects.shots.frame_of(shot), 0)
	_effects.advance(0.0002)
	check_eq(_effects.shots.frame_of(shot), 1)
	_effects.advance(0.0625)
	check_eq(_effects.shots.frame_of(shot), 2)
	_effects.advance(0.0622)
	check_eq(_effects.shots.count(), 1, "still there just before 0.1875 seconds")
	_effects.advance(0.0002)
	check_eq(_effects.shots.count(), 0, "it takes itself away when it has played")
	check_eq(_rows.decor_count(), 0)


func test_the_dust_cloud_is_three_pictures_at_ten_a_second_over_everything() -> void:
	check_eq(_jam.cloud_sprites.size(), 3)
	for sprite in _jam.cloud_sprites:
		check_eq(_rows.atlas.size_of(sprite), Vector2i(18, 14))
	_rows.add_thing(2, Vector2i(2, 9), _tree_sprite, Vector2(0.0, -3.0))
	var shot := _jam.cloud(_effects, 1, Vector2(0.0, 10.0))
	var buffer := PackedFloat32Array()
	var count := _rows.assemble(Rect2(-1e6, -1e6, 2e6, 2e6), buffer)
	var last := (count - 1) * BatchRows.FLOATS
	check_eq(int(buffer[last + 12]), _jam.cloud_sprites[0], "drawn last: over the tree in front")
	var at := JamGrid.cells().position_of(Vector2i(2, 3))
	check_eq(Vector2(buffer[last + 3], buffer[last + 7]), at + Vector2(0.0, 70.0), "10 pixels down")
	_effects.advance(0.1001)
	check_eq(_effects.shots.frame_of(shot), 1)
	_effects.advance(0.1998)
	check_eq(_effects.shots.count(), 1, "still there just before 0.3 seconds")
	_effects.advance(0.0002)
	check_eq(_effects.shots.count(), 0)


func test_effects_follow_the_game_speed_and_the_pause_of_the_game_service() -> void:
	# The four speeds of the jam game. The demo feeds the toolkit the same way.
	var game := GameService.new()
	for speed: float in [1.0, 1.5, 2.0, 3.0]:
		game.speed = speed
		_jam.hit(_effects, _tree)
		var frames := 0
		while _effects.has_effect(_tree) and frames < 100000:
			_effects.advance(0.0001, game.speed, game.paused)
			frames += 1
		check_near(frames * 0.0001, 0.25 / speed, 0.00011, "a hit at x%s" % speed)
	game.speed = 3.0
	_jam.hit(_effects, _tree)
	_effects.advance(0.01, game.speed, game.paused)
	var pose := _effects.pose(_tree)
	game.paused = true
	for frame in 600:
		_effects.advance(1.0 / 60.0, game.speed, game.paused)
	check_eq(_effects.pose(_tree), pose, "ten seconds of pause move nothing")
	game.paused = false
	_effects.advance(0.01, game.speed, game.paused)
	check(_effects.pose(_tree) != pose, "and it goes on afterwards")
	game.free()


func _scale() -> Vector2:
	return _effects.pose(_tree)["scale"]


func _decor_middle() -> Vector2:
	var buffer := PackedFloat32Array()
	_rows.assemble(Rect2(-1e6, -1e6, 2e6, 2e6), buffer)
	return Vector2(buffer[3], buffer[7])
