extends GameTest
## Checks which line of the effect table a sprite reads, and what is written
## there for the shader.

const STEP := EffectsTestKit.STEP
const TREE := 1
const HOUSE := 2
const MEEPLE := 0

var _rows: BatchRows
var _effects: SpriteEffects
var _tree: int
var _house: int
var _meeple: int
var _small: int
var _tall: int
var _wide: int


func before_each() -> void:
	_rows = EffectsTestKit.rows()
	_small = _rows.atlas.find(BatchTestKit.SMALL)
	_tall = _rows.atlas.find(BatchTestKit.TALL)
	_wide = _rows.atlas.find(BatchTestKit.WIDE)
	_rows.add_thing(TREE, Vector2i(2, 3), _tall, BatchTestKit.TALL_OFFSET)
	_rows.add_thing(HOUSE, Vector2i(6, 5), _wide, Vector2(3.5, -3.0))
	_rows.resize_movers(1)
	_rows.place_mover(MEEPLE, Vector2(100.0, 100.0), Color.WHITE, Vector4(float(_small), 0, 0, 1))
	_effects = SpriteEffects.new(_rows, EffectsTestKit.style())
	_tree = SpriteEffects.thing(TREE)
	_house = SpriteEffects.thing(HOUSE)
	_meeple = SpriteEffects.mover(MEEPLE)


func after_each() -> void:
	_effects.close()


func test_a_sprite_with_no_effect_carries_the_number_zero() -> void:
	check_eq(_rows.thing_extra(TREE), 0.0)
	check_eq(_effects.line_of(_tree), EffectTable.NONE)
	_effects.flash(_tree)
	check(_rows.thing_extra(TREE) > 0.0, "with an effect it carries its line")
	_run(96, 1.0)
	check_eq(_rows.thing_extra(TREE), 0.0, "and zero again once the effect is over")
	check_eq(_effects.active_count(), 0)
	check_eq(_effects.table().lines_in_use(), 0)


func test_the_table_line_holds_what_the_shader_reads() -> void:
	_effects.advance(300.0)
	_effects.select(_house, true, Color(0.25, 0.5, 0.75))
	_effects.hover(_house, true)
	_effects.ghost_under(_house, _small, true)
	_effects.reject(_house)
	_effects.squash(_house)
	_effects.wobble(_house)
	_effects.pop(_house)
	var table := _effects.table()
	var line := _effects.line_of(_house)
	var start := 300.0 - SpriteEffects.CLOCK_WRAP
	check_eq(table.read(line, 0), Vector4(3.0, 0.25, 0.5, 0.75), "hovered and selected, the tint")
	check_eq(table.read(line, 1), Vector4(0.75, 0.25, 0.125, 0.0), "blocked ghost colour, no ghost")
	check_eq(table.read(line, 2), Vector4(_small + 1.0, 0.25, 3.5, -3.0), "ghost behind, offset")
	check_eq(table.read(line, 3), Vector4(0.25, 0.5, 0.75, start), "flash colour and start")
	check_eq(table.read(line, 4), Vector4(0.75, 0.0, start, 0.375), "flash fade and hold, shake")
	check_eq(table.read(line, 5), Vector4(4.0, start, 0.75, 0.5625), "shake far, squash, pop fall")
	check_eq(table.read(line, 6), Vector4(1.5, 0.5, start, 0.375), "squash from, wobble")
	var wobble := deg_to_rad(10.0)
	check_near(table.read(line, 7).x, wobble, 0.000001, "wobble angle")
	check_eq(table.read(line, 7).y, start, "pop start")
	check_eq(table.read(line, 7).z, 0.25, "pop amount")
	check_eq(table.read(line, 7).w, 0.1875, "pop rise")


func test_a_start_time_is_written_small_however_late_in_the_game() -> void:
	_effects.advance(36000.0 + 5.0)
	_effects.flash(_tree)
	var start := _effects.table().read(_effects.line_of(_tree), 3).w
	check_eq(start, fmod(36005.0, SpriteEffects.CLOCK_WRAP))
	check(start < SpriteEffects.CLOCK_WRAP, "it is wrapped to the effect clock")
	_run(48, 1.0)
	check_eq(_effects.pose(_tree)["flash"], 0.5, "and the effect still runs right")


func test_a_slot_that_is_not_running_is_written_as_off() -> void:
	_effects.flash(_tree)
	var line := _effects.line_of(_tree)
	var table := _effects.table()
	check_eq(table.read(line, 4).z, -1.0, "shake")
	check_eq(table.read(line, 5).y, -1.0, "squash")
	check_eq(table.read(line, 6).z, -1.0, "wobble")
	check_eq(table.read(line, 7).y, -1.0, "pop")
	check_eq(table.read(line, 3).w, 0.0, "the flash started at clock 0")


func test_many_selected_things_share_one_line() -> void:
	for id in range(10, 510):
		_rows.add_thing(id, Vector2i(id % 40, floori(id / 40.0)), _small)
		_effects.select(SpriteEffects.thing(id), true)
	check_eq(_effects.active_count(), 500)
	check_eq(_effects.table().lines_in_use(), 1)
	var line := _effects.line_of(SpriteEffects.thing(10))
	check_eq(_rows.thing_extra(10), float(line))
	check_eq(_rows.thing_extra(509), float(line))
	check_eq(_effects.table().read(line, 0), Vector4(2.0, 1.0, 1.0, 1.0), "selected, white")


func test_things_that_look_different_do_not_share_a_line() -> void:
	_effects.select(_tree, true)
	_effects.select(_house, true, Color.YELLOW)
	_effects.hover(_meeple, true)
	check_eq(_effects.table().lines_in_use(), 3)
	_effects.select(_house, true, Color.WHITE)
	check_eq(_effects.table().lines_in_use(), 2, "the same look again: the same line")
	check_eq(_effects.line_of(_house), _effects.line_of(_tree))


func test_a_timed_effect_gets_a_line_of_its_own_and_gives_it_back() -> void:
	_effects.select(_tree, true)
	_effects.select(_house, true)
	var shared := _effects.line_of(_tree)
	_effects.flash(_tree)
	var own := _effects.line_of(_tree)
	check(own != shared, "the flashing tree has its own line")
	check_eq(_effects.line_of(_house), shared, "the house stays on the shared line")
	check_eq(_effects.table().read(own, 0).x, 2.0, "the tree is still selected on its own line")
	check_eq(_rows.thing_extra(TREE), float(own))
	_run(96, 1.0)
	check_eq(_effects.line_of(_tree), shared, "after the flash it is back on the shared line")
	check_eq(_rows.thing_extra(TREE), float(shared))
	check_eq(_effects.table().lines_in_use(), 1)


func test_switching_a_lasting_effect_off_frees_its_line() -> void:
	_effects.hover(_tree, true)
	_effects.select(_tree, true)
	_effects.ghost(_tree, true)
	_effects.ghost_under(_tree, _small)
	_effects.hover(_tree, false)
	_effects.select(_tree, false)
	_effects.ghost(_tree, false)
	check(_effects.has_effect(_tree), "the ghost behind it is still on")
	_effects.ghost_under(_tree, SpriteAtlas.NO_SPRITE)
	check(not _effects.has_effect(_tree), "nothing is left")
	check_eq(_rows.thing_extra(TREE), 0.0)
	check_eq(_effects.table().lines_in_use(), 0)


func test_a_ghost_takes_its_colour_and_strength_from_the_style() -> void:
	_effects.ghost(_tree, true)
	var line := _effects.line_of(_tree)
	check_eq(_effects.table().read(line, 1), Vector4(0.125, 0.25, 0.5, 0.75), "ghost colour")
	_effects.ghost(_tree, true, true)
	line = _effects.line_of(_tree)
	check_eq(_effects.table().read(line, 1), Vector4(0.75, 0.25, 0.125, 0.75), "blocked colour")
	_effects.ghost(_tree, false)
	_effects.ghost_under(_house, _small)
	line = _effects.line_of(_house)
	check_eq(_effects.table().read(line, 1), Vector4(0.125, 0.25, 0.5, 0.0), "itself no ghost")
	check_eq(_effects.table().read(line, 2).x, _small + 1.0, "the sprite behind it")
	check_eq(_effects.table().read(line, 2).y, 0.25, "how solid the ghost behind it is")


func test_forget_takes_every_effect_off() -> void:
	_effects.select(_tree, true)
	_effects.flash(_tree)
	_effects.forget(_tree)
	check(not _effects.has_effect(_tree), "no effect is left")
	check_eq(_rows.thing_extra(TREE), 0.0)
	check_eq(_effects.table().lines_in_use(), 0)
	check_eq(_effects.pose(_tree)["flash"], 0.0)


func test_a_sprite_that_is_not_in_the_batch_gets_no_effect() -> void:
	_effects.flash(SpriteEffects.thing(99))
	_effects.select(SpriteEffects.thing(99), true)
	_effects.flash(SpriteEffects.mover(5))
	check_eq(_effects.active_count(), 0)
	check_eq(_effects.table().lines_in_use(), 0)


func test_an_effect_on_a_thing_that_was_taken_away_ends_by_itself() -> void:
	_effects.flash(_tree)
	_rows.remove_thing(TREE)
	_run(96, 1.0)
	check_eq(_effects.active_count(), 0)
	check_eq(_effects.table().lines_in_use(), 0)


func test_close_lets_go_of_everything() -> void:
	_effects.select(_tree, true)
	_effects.flash(_house)
	_effects.shots.play(PackedInt32Array([_small]), 4.0, Vector2i(1, 1))
	_effects.close()
	check_eq(_effects.active_count(), 0)
	check_eq(_effects.shots.count(), 0)
	check_eq(_effects.table().lines_in_use(), 0)
	check_eq(_rows.decor_count(), 0)
	check_eq(_rows.thing_extra(TREE), 0.0)
	check_eq(_rows.thing_extra(HOUSE), 0.0)


func _run(frames: int, speed: float) -> void:
	for frame in frames:
		_effects.advance(STEP, speed)
