extends GameTest
## Checks the picture of the meeples: one mover per row, the glide between two
## ticks, the walking pose, the load, the topple and the fade, and that a
## standing crowd costs the picture nothing.
##
## What the shader then draws from these numbers is proven by pictures: see
## game/dev/stress/README.md.

const WOOD := 1
const STONE := 2

var _village: Village
var _meeples: VillageMeeples
var _stage: MeepleTestKit.Stage
var _start: Vector2


func before_each() -> void:
	_village = MeepleTestKit.village(64)
	_meeples = MeepleTestKit.meeples(_village)
	_stage = MeepleTestKit.Stage.new(_village, tree.current_scene)
	_start = MeepleTestKit.middle()


func after_each() -> void:
	_stage.close()


func test_every_meeple_is_one_mover_with_its_colour_and_its_bounce_start() -> void:
	for index in 3:
		MeepleTestKit.spawn(_village, _start + Vector2(index * 9.0, index * 2.0))
	check_eq(_stage.rows.mover_count(), 3)
	for row in 3:
		var mover := _stage.mover(row)
		check(not mover.is_empty(), "the meeple in row %d is drawn" % row)
		var spot := _start + Vector2(row * 9.0, row * 2.0)
		check_eq(_stage.view.shown_spot(row), _stage.in_batch(spot))
		var tint: Color = mover["tint"]
		check(tint.is_equal_approx(MeepleLook.shirt_colour(_meeples.hues[row])), "its shirt colour")
		var numbers: Vector4 = mover["numbers"]
		check_eq(numbers.x, float(_stage.look.head_sprites[0]), "a bare head")
		check_near(numbers.y, _meeples.bounces[row] * MeepleLook.PHASE_RANGE, 0.0001)
		check_eq(numbers.z, 0.0)
		check_eq(numbers.w, MeepleLook.STANDING)


func test_a_walking_meeple_glides_between_two_ticks() -> void:
	var walker := MeepleTestKit.spawn(_village, _start)
	MeepleTestKit.spawn(_village, _start + Vector2(0.0, 20.0))
	MeepleTestKit.send(_village, walker, _start + Vector2(40.0, 0.0))
	MeepleTestKit.run(_village, 3)
	var from := _meeples.before[0]
	var to := _meeples.spots[0]
	check(to.distance_to(from) > 0.49, "the meeple took a step")
	for fraction: float in [0.0, 0.25, 0.5, 1.0]:
		_stage.view.show_frame(fraction)
		var want := _stage.in_batch(from.lerp(to, fraction))
		check(_stage.view.shown_spot(0).distance_to(want) < 0.001, "at %s of the tick" % fraction)
		var middle: Vector2 = _stage.mover(0)["middle"]
		check(middle.distance_to(want + MeepleLook.BOX_OFFSET * 10.0) < 0.001, "the batch has it")
	# The other one stands still and stays where it is.
	check_eq(_stage.view.shown_spot(1), _stage.in_batch(_start + Vector2(0.0, 20.0)))


func test_a_meeple_shows_the_walking_pose_while_it_walks() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	check_eq(_stage.mover(0)["numbers"].w, MeepleLook.STANDING)
	var target := _start + Vector2(2.0, 0.0)
	MeepleTestKit.send(_village, meeple, target)
	var walking: Vector4 = _stage.mover(0)["numbers"]
	check_eq(walking.w, MeepleLook.WALKING)
	# A walking meeple keeps its own bounce start, so a group does not walk as one block.
	check_near(walking.y, _meeples.bounces[0] * MeepleLook.PHASE_RANGE, 0.0001)
	MeepleTestKit.run(_village, 4)
	_stage.view.show_frame(0.9)
	check_eq(_stage.mover(0)["numbers"].w, MeepleLook.WALKING, "it still glides the last step")
	_village.tick()
	_stage.view.show_frame(0.1)
	check_eq(_stage.mover(0)["numbers"].w, MeepleLook.STANDING)
	check_eq(_stage.view.shown_spot(0), _stage.in_batch(_meeples.spots[0]), "it stands on its spot")
	check(_meeples.spots[0].distance_to(target) < 0.0001)


func test_the_head_shows_what_the_meeple_carries() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	var heads := _stage.look.head_sprites
	var loads: Array[Array] = [
		[WOOD, 1, 2, 0.5], [WOOD, 2, 3, 1.0], [STONE, 1, 4, 0.5], [STONE, 2, 5, 1.0],
		[STONE, 0, 0, 0.0], [77, 1, 0, 0.0],
	]
	for entry in loads:
		_meeples.carry(meeple, entry[0], entry[1])
		var numbers: Vector4 = _stage.mover(0)["numbers"]
		check_eq(numbers.x, float(heads[entry[2]]), "kind %d, %d pieces" % [entry[0], entry[1]])
		check_eq(numbers.z, entry[3], "the head is lifted for the load")
		check_eq(numbers.w, MeepleLook.STANDING)


func test_a_dying_meeple_shows_its_topple_and_its_fade() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	_meeples.carry(meeple, WOOD, 2)
	MeepleTestKit.kill(_village, meeple)
	MeepleTestKit.run(_village, 5)
	_stage.view.show_frame(0.5)
	var mover := _stage.mover(0)
	var numbers: Vector4 = mover["numbers"]
	check_eq(numbers.w, MeepleLook.DYING)
	check_eq(numbers.x, float(_stage.look.head_sprites[3]), "it keeps its load")
	check_eq(numbers.z, 1.0, "and the load stays lifted above its head")
	# Half way between tick 4 and tick 5 of the fall.
	var side := signf(_meeples.topples[0])
	check_near(numbers.y * side, (0.310281 + 0.484814) * 0.5, 0.0001)
	check_near(mover["tint"].a, 1.0, 0.0001)
	MeepleTestKit.run(_village, 4)
	_stage.view.show_frame(1.0)
	check_near(_stage.mover(0)["numbers"].y * side, PI * 0.5, 0.0001, "flat on tick 9")
	# Tick 30 is in the fade: 0.6375 there and 0.7 one tick earlier.
	MeepleTestKit.run(_village, 21)
	_stage.view.show_frame(0.5)
	mover = _stage.mover(0)
	check_near(mover["tint"].a, (0.7 + 0.6375) * 0.5, 0.0001)
	var shirt := MeepleLook.shirt_colour(_meeples.hues[0])
	check_near(mover["tint"].r, shirt.r, 0.0001, "the shirt keeps its colour while it fades")


func test_a_meeple_that_dies_walking_falls_from_the_tilt_it_had() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	MeepleTestKit.send(_village, meeple, _start + Vector2(40.0, 0.0))
	MeepleTestKit.run(_village, 3)
	_stage.batch.clock = 0.31
	var phase := _meeples.bounces[0] * MeepleLook.PHASE_RANGE
	var lean := deg_to_rad(MeepleLook.pose(0.31, phase, true).y)
	check(absf(lean) > 0.01, "the meeple is tilted when it dies: %s" % lean)
	MeepleTestKit.kill(_village, meeple)
	_stage.view.show_frame(1.0)
	check_near(_stage.mover(0)["numbers"].y, lean, 0.0001, "the fall starts from its tilt")
	# The feet stay where the tilted meeple had them.
	var feet := Vector2(0.0, 1.0)
	var want := _stage.in_batch(_meeples.spots[0] + feet.rotated(lean) - feet)
	check(_stage.view.shown_spot(0).distance_to(want) < 0.001, "the feet did not move")
	# Half way down, half of the tilt is left.
	var side := 0.0
	for tick in 9:
		_village.tick()
		side = signf(_meeples.topples[0])
		_stage.view.show_frame(1.0)
		var fallen := absf(_meeples.topples[0]) / (PI * 0.5)
		var shown: float = _stage.mover(0)["numbers"].y
		check_near(shown, _meeples.topples[0] + lean * (1.0 - fallen), 0.0001, "tick %d" % tick)
	check_near(_stage.mover(0)["numbers"].y * side, PI * 0.5, 0.0001, "flat: the tilt is used up")
	# The bounce after landing has nothing of the old tilt in it.
	_village.tick()
	_stage.view.show_frame(1.0)
	check_near(_stage.mover(0)["numbers"].y * side, 1.404502, 0.0001)


func test_a_meeple_that_dies_in_the_middle_of_a_walk_is_glided_to_where_it_died() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	MeepleTestKit.send(_village, meeple, _start + Vector2(40.0, 0.0))
	MeepleTestKit.run(_village, 3)
	var from := _meeples.before[0]
	var died_at := _meeples.spots[0]
	check(died_at.distance_to(from) > 0.49, "it took a step on the tick it dies after")
	_stage.batch.clock = 0.31
	var phase := _meeples.bounces[0] * MeepleLook.PHASE_RANGE
	var lean := deg_to_rad(MeepleLook.pose(0.31, phase, true).y)
	# Its feet stay where the tilted meeple had them, as in the test above.
	var feet := Vector2(0.0, 1.0)
	var shift := feet.rotated(lean) - feet
	MeepleTestKit.kill(_village, meeple)
	_stage.view.show_frame(0.5)
	var half_way := _stage.in_batch(from.lerp(died_at, 0.5) + shift)
	check(_stage.view.shown_spot(0).distance_to(half_way) < 0.001, "half of its last step is shown")
	_village.tick()
	_stage.view.show_frame(0.5)
	var lies := _stage.in_batch(died_at + shift)
	check(_stage.view.shown_spot(0).distance_to(lies) < 0.001, "one tick later it is where it died")


func test_a_meeple_that_dies_standing_falls_from_upright() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	_stage.batch.clock = 0.31
	MeepleTestKit.kill(_village, meeple)
	_stage.view.show_frame(0.0)
	check_eq(_stage.mover(0)["numbers"].y, 0.0)
	check_eq(_stage.view.shown_spot(0), _stage.in_batch(_start))


func test_a_taken_out_meeple_leaves_the_batch_and_the_last_one_takes_its_number() -> void:
	var first := MeepleTestKit.spawn(_village, _start)
	var second := MeepleTestKit.spawn(_village, _start + Vector2(9.0, 0.0))
	var third := MeepleTestKit.spawn(_village, _start + Vector2(18.0, 0.0))
	MeepleTestKit.hold(_village, second)
	MeepleTestKit.hold(_village, third)
	_meeples.carry(third, STONE, 1)
	var third_colour := MeepleLook.shirt_colour(_meeples.hues[2])
	MeepleTestKit.kill(_village, first)
	for tick in 41:
		_village.tick()
		_stage.view.show_frame(0.5)
	check_eq(_stage.rows.mover_count(), 2)
	check_eq(_meeples.row_of(third), 0)
	var mover := _stage.mover(0)
	check_eq(_stage.view.shown_spot(0), _stage.in_batch(_start + Vector2(18.0, 0.0)))
	check(mover["tint"].is_equal_approx(third_colour), "mover 0 is the third meeple now")
	check_eq(mover["numbers"].x, float(_stage.look.head_sprites[4]), "with its stone")
	check_eq(mover["numbers"].w, MeepleLook.STANDING)
	check_eq(_stage.view.shown_spot(1), _stage.in_batch(_start + Vector2(9.0, 0.0)))


func test_a_standing_crowd_costs_the_picture_nothing() -> void:
	for index in 200:
		MeepleTestKit.spawn(_village, _start + Vector2(index % 20, index / 20.0))
	_stage.view.show_frame(0.3)
	var serial := _stage.rows.serial()
	for frame in 30:
		_stage.view.show_frame(frame / 30.0)
	check_eq(_stage.rows.serial(), serial, "nothing was moved, so the batch sends nothing")
	# One meeple walks: the batch is told in every frame.
	MeepleTestKit.send(_village, _meeples.ids[0], _start + Vector2(40.0, 0.0))
	_village.tick()
	serial = _stage.rows.serial()
	_stage.view.show_frame(0.5)
	check(_stage.rows.serial() > serial, "the batch knows that a meeple moved")


func test_a_view_set_up_late_draws_the_meeples_that_are_there() -> void:
	var walker := MeepleTestKit.spawn(_village, _start)
	var dying := MeepleTestKit.spawn(_village, _start + Vector2(0.0, 12.0))
	MeepleTestKit.spawn(_village, _start + Vector2(0.0, 24.0))
	MeepleTestKit.send(_village, walker, _start + Vector2(40.0, 0.0))
	MeepleTestKit.kill(_village, dying)
	MeepleTestKit.run(_village, 30)
	_stage.view.setup(_meeples, _stage.batch, _stage.look)
	check_eq(_stage.rows.mover_count(), 3)
	_stage.view.show_frame(1.0)
	check_eq(_stage.mover(0)["numbers"].w, MeepleLook.WALKING)
	check_eq(_stage.mover(1)["numbers"].w, MeepleLook.DYING)
	check_near(_stage.mover(1)["tint"].a, 0.6375, 0.0001, "tick 30 of its death")
	check_eq(_stage.mover(2)["numbers"].w, MeepleLook.STANDING)


func test_the_view_lets_go_when_the_village_closes() -> void:
	for index in 5:
		MeepleTestKit.spawn(_village, _start + Vector2(index * 9.0, 0.0))
	check_eq(_stage.rows.mover_count(), 5)
	var part: WeakRef = weakref(_meeples)
	_village.close()
	check_eq(_stage.rows.mover_count(), 0, "no meeple is drawn any more")
	_stage.view.show_frame(0.5)
	_meeples = null
	check(part.get_ref() == null, "the view does not hold on to the meeples of a closed village")
