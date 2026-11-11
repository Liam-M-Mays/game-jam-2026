extends GameTest
## Checks that effects run on game time: faster at a higher game speed, and
## frozen while the game is paused.

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


func test_at_three_times_speed_every_effect_takes_a_third_of_the_time() -> void:
	# Each effect of the sample style, and how many test frames it lasts at x1.
	var lengths := {"flash": 96, "shake": 48, "squash": 96, "grow_in": 192, "wobble": 48, "pop": 96}
	for effect: String in lengths:
		var frames: int = lengths[effect]
		check_eq(_frames_until_over(effect, 1.0), frames, "%s at x1" % effect)
		@warning_ignore("integer_division")
		check_eq(_frames_until_over(effect, 3.0), frames / 3, "%s at x3" % effect)


func test_at_three_times_speed_an_effect_is_as_far_after_one_frame_as_after_three() -> void:
	for effect: String in ["flash", "shake", "squash", "grow_in", "wobble", "pop"]:
		for frames: int in [1, 5, 11]:
			_start(effect, _tree)
			_run(frames, 3.0)
			var fast := _effects.pose(_tree)
			_effects.forget(_tree)
			_start(effect, _tree)
			_run(frames * 3, 1.0)
			check_eq(fast, _effects.pose(_tree), "%s after %d frames at x3" % [effect, frames])
			_effects.forget(_tree)


func test_other_speeds_scale_the_same_way() -> void:
	_effects.flash(_tree)
	_effects.advance(0.25, 1.5)
	check_eq(_effects.pose(_tree)["flash"], 0.5, "0.375 of 0.75 seconds are gone")
	_effects.forget(_tree)
	_effects.flash(_tree)
	_effects.advance(0.25, 2.0)
	check_near(_effects.pose(_tree)["flash"], 1.0 / 3.0, 0.000001, "0.5 of 0.75 seconds are gone")


func test_no_effect_moves_while_the_game_is_paused() -> void:
	_effects.flash(_tree)
	_effects.shake(_tree)
	_effects.squash(_tree)
	_effects.wobble(_tree)
	_effects.pop(_tree)
	var shot := _effects.shots.play(PackedInt32Array([_small, _wide, _tall]), 4.0, Vector2i(1, 1))
	_run(40, 1.0)
	var pose := _effects.pose(_tree)
	var clock := _effects.clock()
	check_eq(_effects.shots.frame_of(shot), 1, "the one-shot is on its second picture")
	check(pose["flash"] < 1.0 and pose["scale"] != Vector2.ONE, "the effects are under way")
	for frame in 500:
		_effects.advance(STEP, 1.0, true)
		_effects.advance(STEP, 3.0, true)
	check_eq(_effects.clock(), clock, "the effect clock stands still")
	check_eq(_effects.pose(_tree), pose, "the sprite is exactly where it was")
	check_eq(_effects.shots.frame_of(shot), 1, "the one-shot shows the same picture")
	check(_effects.has_effect(_tree), "and nothing has ended")
	_run(1, 1.0)
	check(_effects.pose(_tree) != pose, "it goes on from there when the game runs again")


func test_the_effect_clock_is_game_time() -> void:
	_effects.advance(2.0, 1.0)
	_effects.advance(2.0, 3.0)
	_effects.advance(2.0, 1.0, true)
	_effects.advance(-1.0, 1.0)
	check_eq(_effects.clock(), 8.0)


func test_a_one_shot_takes_a_third_of_the_time_at_three_times_speed() -> void:
	var frames := PackedInt32Array([_small, _wide, _tall])
	_effects.shots.play(frames, 4.0, Vector2i(2, 3))
	var at_x1 := 0
	while _effects.shots.count() > 0 and at_x1 < 1000:
		_effects.advance(STEP, 1.0)
		at_x1 += 1
	_effects.shots.play(frames, 4.0, Vector2i(2, 3))
	var at_x3 := 0
	while _effects.shots.count() > 0 and at_x3 < 1000:
		_effects.advance(STEP, 3.0)
		at_x3 += 1
	check_eq(at_x1, 96)
	check_eq(at_x3, 32)


func _start(effect: String, target: int) -> void:
	_effects.call(effect, target)


func _run(frames: int, speed: float) -> void:
	for frame in frames:
		_effects.advance(STEP, speed)


## Starts [param effect] on the tree and counts the test frames until it is over.
func _frames_until_over(effect: String, speed: float) -> int:
	_start(effect, _tree)
	var frames := 0
	while _effects.has_effect(_tree) and frames < 10000:
		_effects.advance(STEP, speed)
		frames += 1
	return frames
