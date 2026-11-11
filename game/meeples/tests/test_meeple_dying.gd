extends GameTest
## Checks dying: the topple and the fade tick by tick, the side, that a dying
## meeple freezes, and that it is taken out when it has faded.
##
## The expected numbers are worked out by hand from the jam game's tween:
## fall to 90 degrees in 0.45 s (faster and faster), bounce back 0.2 radians
## in 0.08 s and down again in 0.08 s, lie 0.6 s, fade in 0.8 s. A test
## village runs 20 ticks a second, so tick 9 is 0.45 s.

## The topple after each of the first 14 ticks, in radians.
const TOPPLES: Array[float] = [
	0.019393, 0.077570, 0.174533, 0.310281, 0.484814, 0.698132, 0.950235,
	1.241123, 1.570796, 1.404502, 1.386020, 1.531778, 1.570796, 1.570796,
]
## The fade after some ticks. The fade starts 1.21 s after the death.
const FADES: Dictionary[int, float] = {
	1: 1.0, 13: 1.0, 24: 1.0, 25: 0.95, 26: 0.8875, 30: 0.6375, 35: 0.325, 40: 0.0125,
}

var _village: Village
var _meeples: VillageMeeples
var _died: Array[Array] = []
var _removed: Array[int] = []


func before_each() -> void:
	_village = MeepleTestKit.village(64)
	_meeples = MeepleTestKit.meeples(_village)
	_meeples.meeple_died.connect(_note_died)
	_meeples.meeple_removed.connect(_note_removed)


func test_the_topple_follows_the_jam_curve_tick_by_tick() -> void:
	var meeple := MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	MeepleTestKit.kill(_village, meeple)
	check_eq(_meeples.topples[0], 0.0, "it starts upright")
	var side := 0.0
	for tick in TOPPLES.size():
		var topple_before := _meeples.topples[0]
		_village.tick()
		if tick == 0:
			side = signf(_meeples.topples[0])
			check(side != 0.0, "it falls to one side")
		check_near(_meeples.topples[0] * side, TOPPLES[tick], 0.00001, "tick %d" % (tick + 1))
		check_eq(_meeples.topples_before[0], topple_before, "the value of the tick before is kept")
	# It lies flat until it is gone.
	MeepleTestKit.run(_village, 26)
	check_near(_meeples.topples[0] * side, PI * 0.5, 0.00001)


func test_the_fade_follows_the_jam_curve_tick_by_tick() -> void:
	var meeple := MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	MeepleTestKit.kill(_village, meeple)
	check_eq(_meeples.fades[0], 1.0)
	for tick in range(1, 41):
		var fade_before := _meeples.fades[0]
		_village.tick()
		if FADES.has(tick):
			check_near(_meeples.fades[0], FADES[tick], 0.00001, "tick %d" % tick)
		check_eq(_meeples.fades_before[0], fade_before, "the value of the tick before is kept")
		check(_meeples.fades[0] <= fade_before, "it never gets more solid again")


func test_a_dead_meeple_is_taken_out_when_it_has_faded() -> void:
	var meeple := MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	MeepleTestKit.kill(_village, meeple)
	# 0.45 + 0.08 + 0.08 + 0.6 + 0.8 = 2.01 seconds. The first tick after that is tick 41.
	MeepleTestKit.run(_village, 40)
	check_eq(_meeples.count(), 1, "after 2.0 seconds it is still fading")
	check_eq(_removed, [] as Array[int])
	_village.tick()
	check_eq(_meeples.count(), 0)
	check_eq(_removed, [meeple] as Array[int])
	check_eq(_meeples.dying.size(), 0)
	check(not _meeples.has_meeple(meeple))


func test_a_dying_meeple_is_stepped_and_a_living_one_is_not() -> void:
	var meeple := MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	var other := MeepleTestKit.spawn(_village, MeepleTestKit.middle() + Vector2(8.0, 0.0))
	MeepleTestKit.hold(_village, other)
	_village.tick()
	var steps := _meeples.steps
	MeepleTestKit.kill(_village, meeple)
	check_eq(_meeples.dying.size(), 1)
	check_eq(int(_meeples.states[0]), VillageMeeples.DYING)
	MeepleTestKit.run(_village, 41)
	check_eq(_meeples.steps - steps, 41, "one step a tick for the dying one, none for the other")
	check_eq(_meeples.count(), 1)
	check_eq(_meeples.ids[0], other)
	check_eq(_meeples.fades[0], 1.0, "the living one is as solid as before")


func test_the_side_is_random_and_comes_from_the_village() -> void:
	var right := 0
	for index in 1000:
		var meeple := MeepleTestKit.spawn(_village, MeepleTestKit.middle())
		MeepleTestKit.kill(_village, meeple)
	_village.tick()
	for row in 1000:
		check_near(absf(_meeples.topples[row]), TOPPLES[0], 0.00001)
		if _meeples.topples[row] > 0.0:
			right += 1
	check(right > 440 and right < 560, "%d of 1000 fell to the right, 500 are expected" % right)
	# The same seed gives the same sides.
	var twin := MeepleTestKit.village(64)
	for index in 1000:
		MeepleTestKit.kill(twin, MeepleTestKit.spawn(twin, MeepleTestKit.middle()))
	twin.tick()
	check_eq(MeepleTestKit.meeples(twin).topples, _meeples.topples)


func test_a_dying_meeple_freezes_where_it_is() -> void:
	var start := MeepleTestKit.middle()
	var meeple := MeepleTestKit.spawn(_village, start)
	MeepleTestKit.send(_village, meeple, start + Vector2(50.0, 0.0))
	MeepleTestKit.run(_village, 6)
	var spot := _meeples.spots[0]
	check(spot.distance_to(start + Vector2(3.0, 0.0)) < 0.0001, "it walked 3 art pixels")
	MeepleTestKit.kill(_village, meeple)
	check_eq(_meeples.walkers.size(), 0, "it does not walk any more")
	check_eq(int(_meeples.walking[0]), 1, "it keeps the pose it died in")
	_village.tick()
	check_eq(_meeples.before[0], spot, "the picture has glided the last step in")
	for tick in 39:
		_village.tick()
		check_eq(_meeples.spots[0], spot)
	check(not _meeples.walk_to(_village, meeple, start), "a dying meeple takes no job")
	check(not _meeples.halt(meeple))
	check(not _meeples.release(_village, meeple))
	check_eq(int(_meeples.states[0]), VillageMeeples.DYING)


func test_a_death_is_told_once_with_the_spot() -> void:
	var spot := MeepleTestKit.middle() + Vector2(4.0, 2.0)
	var meeple := MeepleTestKit.spawn(_village, spot)
	check_eq(_village.timers.sleeping(), 1)
	MeepleTestKit.kill(_village, meeple)
	check_eq(_died, [[meeple, spot]], "the hurt sound has an event to listen to")
	check_eq(_village.timers.sleeping(), 0, "its wake-up timer is stopped")
	MeepleTestKit.run(_village, 41)
	check_eq(_died.size(), 1)


func test_a_meeple_keeps_its_load_while_it_dies() -> void:
	var meeple := MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	_meeples.carry(meeple, 2, 2)
	MeepleTestKit.kill(_village, meeple)
	MeepleTestKit.run(_village, 20)
	check_eq(_meeples.load_kinds[0], 2)
	check_eq(int(_meeples.load_counts[0]), 2)


func test_the_curve_has_the_jam_numbers() -> void:
	check_eq(MeepleTopple.angle_at(0.0), 0.0)
	check_near(MeepleTopple.angle_at(0.225), PI * 0.5 * 0.25, 0.000001, "a quarter at half time")
	check_near(MeepleTopple.angle_at(0.45), PI * 0.5, 0.000001, "flat after 0.45 s")
	check_near(MeepleTopple.angle_at(0.53), PI * 0.5 - 0.2, 0.000001, "0.2 radians back up")
	check_near(MeepleTopple.angle_at(0.61), PI * 0.5, 0.000001, "down again 0.08 s later")
	check_near(MeepleTopple.angle_at(5.0), PI * 0.5, 0.000001)
	check_eq(MeepleTopple.fade_at(0.0), 1.0)
	check_eq(MeepleTopple.fade_at(1.21), 1.0)
	check_near(MeepleTopple.fade_at(1.61), 0.5, 0.000001, "half gone 0.4 s into the fade")
	check_eq(MeepleTopple.fade_at(2.02), 0.0)
	check_near(MeepleTopple.fade_starts_at(), 1.21, 0.000001)
	check(not MeepleTopple.is_over(2.0) and MeepleTopple.is_over(2.02), "about 2.0 s in total")


func test_the_topple_is_the_same_curve_at_another_tick_rate() -> void:
	var village := MeepleTestKit.village(64, 60)
	var meeples := MeepleTestKit.meeples(village)
	MeepleTestKit.kill(village, MeepleTestKit.spawn(village, MeepleTestKit.middle()))
	MeepleTestKit.run(village, 27)
	check_near(absf(meeples.topples[0]), PI * 0.5, 0.00001, "27 ticks of 60 are 0.45 s")
	MeepleTestKit.run(village, 93)
	check_eq(meeples.count(), 1, "2.0 s: still there")
	MeepleTestKit.run(village, 1)
	check_eq(meeples.count(), 0, "121 ticks of 60 are past 2.01 s")


func _note_died(meeple: int, spot: Vector2) -> void:
	_died.append([meeple, spot])


func _note_removed(meeple: int, _row: int, _moved_from: int) -> void:
	_removed.append(meeple)
