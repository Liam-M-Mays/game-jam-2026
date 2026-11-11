extends GameTest
## Checks walking: the two jam speeds in exact numbers, the straight line, the
## aim below the target, stopping on the thing a meeple is sent to, and what
## the picture needs for its glide.
##
## A village works in art pixels. Ten jam units are one art pixel, so the jam
## game's 100 units a second are 10 art pixels a second. Positions are 32-bit
## numbers, so a spot is compared to a ten-thousandth of an art pixel.

## How close two spots must be to count as the same, in art pixels.
const CLOSE := 0.0001

var _village: Village
var _meeples: VillageMeeples
var _arrived: Array[int] = []
var _start: Vector2


func before_each() -> void:
	_village = MeepleTestKit.village(64)
	_meeples = MeepleTestKit.meeples(_village)
	_meeples.meeple_arrived.connect(_note_arrived)
	_start = MeepleTestKit.middle()


func test_a_meeple_on_a_job_walks_100_jam_units_a_second() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	MeepleTestKit.send(_village, meeple, _start + Vector2(200.0, 0.0))
	for tick in 20:
		var from := _meeples.spots[0]
		_village.tick()
		check_near(_meeples.spots[0].distance_to(from), 0.5, CLOSE, "5 jam units a tick")
	# One second: 10 art pixels, which is 100 jam units.
	_check_spot(_meeples.spots[0], _start + Vector2(10.0, 0.0))
	check_near(_meeples.spots[0].distance_to(_start) / MeepleNumbers.UNIT, 100.0, 0.001)
	check_near(MeepleNumbers.JOB_SPEED / MeepleNumbers.UNIT, 100.0, 0.000001)


func test_a_wandering_meeple_strolls_30_jam_units_a_second() -> void:
	MeepleTestKit.spawn(_village, _start)
	var full_strides := 0
	var last_move := 0.0
	for tick in 4000:
		var from := _meeples.spots[0]
		_village.tick()
		var moved := _meeples.spots[0].distance_to(from)
		if moved > 0.0 and last_move > 0.0:
			# Every step of a stroll but its last one is a full stride.
			check_near(last_move, 0.15, CLOSE, "1.5 jam units a tick")
			full_strides += 1
		last_move = moved
	check(full_strides > 300, "the meeple strolled: %d full strides" % full_strides)
	check_near(MeepleNumbers.WANDER_SPEED / MeepleNumbers.UNIT, 30.0, 0.000001)


func test_the_speed_is_the_same_at_another_tick_rate() -> void:
	var village := MeepleTestKit.village(64, 60)
	var meeples := MeepleTestKit.meeples(village)
	var meeple := MeepleTestKit.spawn(village, _start)
	MeepleTestKit.send(village, meeple, _start + Vector2(200.0, 0.0))
	MeepleTestKit.run(village, 60)
	# 60 ticks are one second there.
	check(meeples.spots[0].distance_to(_start + Vector2(10.0, 0.0)) < 0.001, "10 art pixels")


func test_a_walk_is_a_straight_line_that_ends_on_the_target() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	var point := _start + Vector2(13.3, -7.4)
	var target := point + MeepleNumbers.AIM_BELOW
	_meeples.walk_to(_village, meeple, point)
	var way := (target - _start).normalized()
	var length := _start.distance_to(target)
	var ticks := ceili(length / 0.5)
	check_eq(ticks, 31)
	for tick in ticks:
		_village.tick()
		var walked := _meeples.spots[0] - _start
		check_near(way.cross(walked), 0.0, 0.001, "the meeple left the straight line")
		check_near(walked.length(), minf((tick + 1) * 0.5, length), 0.001)
	check_eq(_meeples.spots[0], target, "the last step lands on the target itself")


func test_a_meeple_aims_3_jam_units_below_the_point_it_is_sent_to() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	var point := _start + Vector2(6.0, -4.0)
	_meeples.walk_to(_village, meeple, point)
	MeepleTestKit.run(_village, 40)
	check_eq(_meeples.spots[0], point + MeepleNumbers.AIM_BELOW)
	check_near(_meeples.spots[0].y - point.y, 0.3, CLOSE)
	check_near(_meeples.spots[0].x, point.x, CLOSE)


func test_a_walk_is_over_one_tick_after_its_last_step() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	MeepleTestKit.send(_village, meeple, _start + Vector2(2.0, 0.0))
	check_eq(int(_meeples.walking[0]), 1, "it shows the walking pose at once")
	check_eq(int(_meeples.states[0]), VillageMeeples.ON_JOB)
	# 2 art pixels are 4 steps.
	MeepleTestKit.run(_village, 4)
	_check_spot(_meeples.spots[0], _start + Vector2(2.0, 0.0))
	check_eq(int(_meeples.walking[0]), 1, "the picture still glides the last step in")
	check_eq(_arrived, [] as Array[int])
	_village.tick()
	check_eq(int(_meeples.walking[0]), 0)
	check_eq(_arrived, [meeple] as Array[int])
	check_eq(_meeples.walkers.size(), 0, "it is not stepped any more")
	# It waits for its job and does not wander off.
	var steps := _meeples.steps
	MeepleTestKit.run(_village, 200)
	check_eq(_meeples.steps, steps)
	_check_spot(_meeples.spots[0], _start + Vector2(2.0, 0.0))
	check_eq(_arrived.size(), 1, "it arrived once")


func test_the_picture_can_glide_from_the_spot_before_to_the_spot_now() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	check_eq(_meeples.before[0], _start, "a standing meeple was where it is")
	MeepleTestKit.send(_village, meeple, _start + Vector2(1.5, 0.0))
	_village.tick()
	check_eq(_meeples.before[0], _start)
	_check_spot(_meeples.spots[0], _start + Vector2(0.5, 0.0))
	var first_step := _meeples.spots[0]
	_village.tick()
	check_eq(_meeples.before[0], first_step)
	_check_spot(_meeples.spots[0], _start + Vector2(1.0, 0.0))
	MeepleTestKit.run(_village, 2)
	check_eq(_meeples.before[0], _meeples.spots[0], "once it stands, both are the same again")
	_check_spot(_meeples.spots[0], _start + Vector2(1.5, 0.0))


func test_a_meeple_stops_on_the_first_cell_of_the_thing_it_is_sent_to() -> void:
	var anchor := Vector2i(36, 20)
	var thing := MeepleTestKit.place_thing(_village, anchor, 2, 2)
	var meeple := MeepleTestKit.spawn(_village, _start)
	var point := GridLayout.position_of(anchor + Vector2i(1, 1))
	_meeples.walk_to(_village, meeple, point, thing)
	var last_step_from := _start
	for tick in 400:
		var from := _meeples.spots[0]
		_village.tick()
		if _meeples.spots[0] != from:
			last_step_from = from
		if _meeples.walking[0] == 0:
			break
	var cell := GridLayout.cell_under(_meeples.spots[0])
	check_eq(_village.grid.occupant(cell), thing, "it stands on a cell of the thing")
	var cell_before := GridLayout.cell_under(last_step_from)
	check(_village.grid.occupant(cell_before) != thing, "one step earlier it was not on it yet")
	check(_meeples.spots[0].distance_to(point) > 3.0, "it did not walk on to the middle")
	check_eq(_arrived, [meeple] as Array[int])


func test_a_meeple_walks_right_up_to_a_point_with_no_thing() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	var drop := GridLayout.position_of(Vector2i(36, 20))
	_meeples.walk_to(_village, meeple, drop)
	MeepleTestKit.run(_village, 400)
	check_eq(_meeples.spots[0], drop + MeepleNumbers.AIM_BELOW)
	check_eq(_arrived, [meeple] as Array[int])


func test_a_meeple_that_is_there_already_arrives_on_the_next_tick() -> void:
	var thing := MeepleTestKit.place_thing(_village, Vector2i(30, 20))
	var meeple := MeepleTestKit.spawn(_village, _start)
	# One jam unit from the target counts as there.
	MeepleTestKit.send(_village, meeple, _start + Vector2(0.09, 0.0))
	check_eq(int(_meeples.walking[0]), 0, "no walking pose for a walk of no steps")
	check_eq(_arrived, [] as Array[int], "the news comes on a tick, not inside the call")
	_village.tick()
	check_eq(_arrived, [meeple] as Array[int])
	check_eq(_meeples.spots[0], _start)
	# The same when it already stands on the thing it is sent to.
	_meeples.walk_to(_village, meeple, _start + Vector2(30.0, 0.0), thing)
	_village.tick()
	check_eq(_arrived, [meeple, meeple] as Array[int])
	check_eq(_meeples.spots[0], _start)
	# Just over one jam unit is a walk.
	MeepleTestKit.send(_village, meeple, _start + Vector2(0.11, 0.0))
	check_eq(int(_meeples.walking[0]), 1)


func test_a_meeple_can_be_sent_somewhere_else_while_it_walks() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	MeepleTestKit.send(_village, meeple, _start + Vector2(50.0, 0.0))
	MeepleTestKit.run(_village, 4)
	MeepleTestKit.send(_village, meeple, _start + Vector2(2.0, 5.0))
	check_eq(_meeples.walkers.size(), 1, "it is in the list of walkers once")
	MeepleTestKit.run(_village, 11)
	_check_spot(_meeples.spots[0], _start + Vector2(2.0, 5.0))
	check_eq(_arrived, [meeple] as Array[int])


func test_halt_stops_a_meeple_where_it_is() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	check(not _meeples.halt(meeple), "a standing meeple cannot be stopped")
	MeepleTestKit.send(_village, meeple, _start + Vector2(50.0, 0.0))
	MeepleTestKit.run(_village, 6)
	check(_meeples.halt(meeple))
	MeepleTestKit.run(_village, 5)
	_check_spot(_meeples.spots[0], _start + Vector2(3.0, 0.0))
	check_eq(int(_meeples.walking[0]), 0)
	check_eq(_arrived, [meeple] as Array[int])


func test_a_meeple_let_go_while_walking_finishes_its_walk_and_then_wanders() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	var target := _start + Vector2(8.0, 0.0)
	MeepleTestKit.send(_village, meeple, target)
	MeepleTestKit.run(_village, 3)
	check(_meeples.release(_village, meeple))
	check_eq(int(_meeples.states[0]), VillageMeeples.FREED)
	check(not _meeples.release(_village, meeple), "it can be let go once")
	# It keeps the job speed to the end of this walk: 8 art pixels are 16 steps.
	MeepleTestKit.run(_village, 13)
	_check_spot(_meeples.spots[0], target)
	_village.tick()
	check_eq(int(_meeples.states[0]), VillageMeeples.IDLE)
	check_eq(_meeples.homes[0], _meeples.spots[0], "where it stopped is its home")
	check_eq(_arrived, [] as Array[int], "no job is told: it has none")
	check_eq(_village.timers.sleeping(), 1, "it pauses before its first stroll")
	# Its strolls stay around the new home: 60 jam units at most.
	var furthest := 0.0
	for tick in 2000:
		_village.tick()
		furthest = maxf(furthest, _meeples.spots[0].distance_to(target))
	check(furthest > 1.0 and furthest <= 6.001, "it strolled %s art pixels from home" % furthest)


func test_a_meeple_let_go_while_standing_wanders_at_once() -> void:
	var meeple := MeepleTestKit.spawn(_village, _start)
	MeepleTestKit.hold(_village, meeple)
	_village.tick()
	check_eq(_village.timers.sleeping(), 0, "a meeple on a job has no wake-up timer")
	check(_meeples.release(_village, meeple))
	check_eq(int(_meeples.states[0]), VillageMeeples.IDLE)
	check_eq(_village.timers.sleeping(), 1)
	check(not _meeples.release(_village, 9999))


func test_nobody_can_be_sent_who_is_not_there() -> void:
	check(not _meeples.walk_to(_village, 9999, _start))
	check(not _meeples.halt(9999))
	check_eq(_meeples.walkers.size(), 0)


func _check_spot(got: Vector2, want: Vector2) -> void:
	check(got.distance_to(want) < CLOSE, "got %s, want %s" % [got, want])


func _note_arrived(meeple: int) -> void:
	_arrived.append(meeple)
