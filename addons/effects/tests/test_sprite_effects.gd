extends GameTest
## Checks the effects themselves with no window: the named slots, the numbers
## of the style, and that every sprite is called the same way.

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


func test_a_new_effect_in_a_slot_takes_the_place_of_the_old_one() -> void:
	_effects.flash(_tree, Color.RED)
	_run(48, 1.0)
	check_eq(_effects.pose(_tree)["flash"], 0.5)
	_effects.flash(_tree, Color.BLUE)
	check_eq(_effects.pose(_tree)["flash"], 1.0, "the new flash starts full")
	check_eq(_effects.pose(_tree)["flash_colour"], Color.BLUE)
	_run(48, 1.0)
	check_eq(_effects.pose(_tree)["flash"], 0.5, "the old flash would be over by now")
	_run(48, 1.0)
	check(not _effects.has_effect(_tree), "it ends one flash time after the second start")


func test_grow_in_and_squash_share_one_slot() -> void:
	_effects.squash(_tree)
	_run(10, 1.0)
	_effects.grow_in(_tree)
	check_eq(_effects.pose(_tree)["scale"], Vector2(0.5, 0.25), "the squash is gone")
	_run(192, 1.0)
	check(not _effects.has_effect(_tree), "and nothing of it is left after the grow in")


func test_effects_in_different_slots_play_at_the_same_time() -> void:
	_effects.flash(_tree, Color.GREEN)
	_effects.shake(_tree)
	_effects.squash(_tree)
	_effects.wobble(_tree)
	_effects.pop(_tree)
	_run(12, 1.0)
	var age := 12 * STEP
	var pose := _effects.pose(_tree)
	check_eq(pose["flash"], EffectCurves.flash_amount(age, 0.0, 0.75))
	check_eq(pose["flash_colour"], Color.GREEN)
	check_eq(pose["shift"], EffectCurves.shake_offset(age, 0.375, 4.0))
	var squash := EffectCurves.squash_scale(age, 0.75, Vector2(1.5, 0.5))
	check_eq(pose["scale"], squash * EffectCurves.pop_scale(age, 0.25, 0.1875, 0.5625))
	check_near(pose["degrees"], rad_to_deg(EffectCurves.wobble_angle(age, 0.375, deg_to_rad(10.0))))
	check(pose["shift"] != 0.0 and pose["degrees"] != 0.0, "each of them is really running")


func test_the_numbers_of_an_effect_come_from_the_style() -> void:
	_effects.reject(_tree)
	check_eq(_effects.pose(_tree)["flash_colour"], EffectsTestKit.REJECT)
	_run(6, 1.0)
	check_near(_effects.pose(_tree)["shift"], 2.5, 0.000001, "an eighth of the way: 2.5 of 4")
	_effects.forget(_tree)
	_effects.squash(_tree)
	check_eq(_effects.pose(_tree)["scale"], Vector2(1.5, 0.5))
	_effects.squash(_tree, 0.25)
	check_eq(_effects.pose(_tree)["scale"], Vector2(1.25, 0.75), "an amount of its own")
	_effects.pop(_tree)
	_run(24, 1.0)
	check_near(_effects.pose(_tree)["scale"].x / EffectCurves.squash_scale(
		24 * STEP, 0.75, Vector2(1.25, 0.75)
	).x, 1.25, 0.000001, "the pop is at its top of 125 percent")
	_effects.forget(_tree)
	_effects.wobble(_tree, 20.0)
	_run(12, 1.0)
	check_near(_effects.pose(_tree)["degrees"], 20.0, 0.000001, "an angle of its own")


func test_a_tree_a_building_and_a_meeple_are_called_the_same_way() -> void:
	for target: int in [_tree, _house, _meeple]:
		_effects.flash(target, Color.RED)
		_effects.shake(target)
		_effects.squash(target)
		_effects.wobble(target)
		_effects.pop(target)
		_effects.hover(target, true)
		_effects.select(target, true)
	_run(20, 1.0)
	var tree := _effects.pose(_tree)
	check(tree["flash"] < 1.0 and tree["shift"] != 0.0, "the effects are under way")
	check_eq(_effects.pose(_house), tree)
	check_eq(_effects.pose(_meeple), tree)
	check_eq(_rows.thing_extra(TREE), float(_effects.line_of(_tree)))
	check_eq(_rows.thing_extra(HOUSE), float(_effects.line_of(_house)))
	check_eq(_rows.mover_extra(MEEPLE), float(_effects.line_of(_meeple)))
	var lines := [_effects.line_of(_tree), _effects.line_of(_house), _effects.line_of(_meeple)]
	check(not lines.has(EffectTable.NONE), "each has a line of the effect table")
	check(lines[0] != lines[1] and lines[1] != lines[2] and lines[0] != lines[2], "of its own")


func _run(frames: int, speed: float) -> void:
	for frame in frames:
		_effects.advance(STEP, speed)
