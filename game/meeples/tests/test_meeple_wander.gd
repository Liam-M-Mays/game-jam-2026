extends GameTest
## Checks the wander rules of the jam game: the pause, the stroll around the
## home, the hangout, the spot near it and the change of hangout.
##
## Ten jam units are one art pixel. So the jam game's 60 units are 6 art
## pixels, and its nudge of 12 by 6 units is 1.2 by 0.6 art pixels. The reach
## for changing hangout is the one exception: it is 100 art pixels.
##
## These tests ask the wander rules by hand. test_meeple_strolls.gd checks
## the same rules on a meeple that ticks.

var _village: Village
var _meeples: VillageMeeples
var _wander: MeepleWander


func before_each() -> void:
	_village = MeepleTestKit.village(64)
	_meeples = MeepleTestKit.meeples(_village)
	_wander = _meeples.wander


func test_a_pause_is_between_1_and_3_5_seconds() -> void:
	var shortest := 1000
	var longest := 0
	var seen: Dictionary[int, bool] = {}
	for index in 3000:
		var ticks := _wander.pause_ticks(_village)
		shortest = mini(shortest, ticks)
		longest = maxi(longest, ticks)
		seen[ticks] = true
	check_eq(shortest, 20, "1.0 second is 20 ticks")
	check_eq(longest, 70, "3.5 seconds are 70 ticks")
	check_eq(seen.size(), 51, "every length from 20 to 70 ticks comes up")


func test_with_no_hangout_a_stroll_goes_15_to_60_jam_units_from_home() -> void:
	var home := MeepleTestKit.middle()
	var nearest := 1000.0
	var furthest := 0.0
	var quarters: Dictionary[Vector2i, bool] = {}
	for index in 2000:
		var spot := _wander.next_spot(_village, home, home, MeepleWander.NO_HANGOUT)
		var distance := spot.distance_to(home)
		nearest = minf(nearest, distance)
		furthest = maxf(furthest, distance)
		quarters[Vector2i((spot - home).sign())] = true
	check(nearest >= 1.4999 and nearest < 1.6, "the nearest spot is %s art pixels away" % nearest)
	check(furthest <= 6.0001 and furthest > 5.9, "the furthest spot is %s art pixels away" % furthest)
	check(quarters.size() >= 4, "the strolls go in every direction")


func test_a_stroll_around_home_never_leaves_the_grid() -> void:
	# The home is on the corner cell. Most spots around it are off the grid.
	var home := GridLayout.position_of(Vector2i.ZERO)
	var found := 0
	for index in 500:
		var spot := _wander.spot_around(_village, home)
		if spot.is_finite():
			found += 1
			check(_village.grid.cell_at(spot) != GridLayout.NO_CELL, "a spot off the grid")
	check(found > 300, "8 tries find a spot on the grid most of the time: %d of 500" % found)


func test_a_meeple_with_nowhere_to_go_stays_put() -> void:
	# Far outside the grid no spot is on a cell. It tries 8 spots and gives up.
	var nowhere := Vector2(-5000.0, -5000.0)
	var state := _village.rng.state
	check(not _wander.spot_around(_village, nowhere).is_finite(), "no spot")
	var twin := RandomNumberGenerator.new()
	twin.state = state
	for attempt in 8:
		twin.randf()
		twin.randf_range(1.5, 6.0)
	check_eq(_village.rng.state, twin.state, "8 tries, two random numbers each")
	MeepleTestKit.spawn(_village, nowhere)
	MeepleTestKit.run(_village, 600)
	check_eq(_meeples.spots[0], nowhere)
	check_eq(_meeples.steps, 0, "it never walked")
	check_eq(_village.timers.sleeping(), 1, "it pauses again and again")
	check(_village.timers.steps >= 8, "it woke %d times" % _village.timers.steps)


func test_a_meeple_that_goes_idle_takes_the_nearest_hangout() -> void:
	var far := MeepleTestKit.place_thing(_village, Vector2i(5, 5), 2, 2)
	var near := MeepleTestKit.place_thing(_village, Vector2i(33, 20), 2, 2)
	var tree := MeepleTestKit.place_thing(_village, Vector2i(31, 20))
	check(_wander.add_hangout(_village, far))
	check(_wander.add_hangout(_village, near))
	check(not _wander.add_hangout(_village, near), "a thing is a hangout once")
	check(not _wander.add_hangout(_village, 9999), "a hangout has to stand on the grid")
	check_eq(_wander.hangout_count(), 2)
	MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	check_eq(_meeples.hangouts[0], near, "the tree next to it is no hangout")
	check(not _wander.has_hangout(tree))
	check_eq(_wander.nearest_hangout(GridLayout.position_of(Vector2i(6, 6))), far)
	# With no hangout at all a meeple has none.
	var empty := MeepleTestKit.village(1)
	MeepleTestKit.spawn(empty, MeepleTestKit.middle())
	check_eq(MeepleTestKit.meeples(empty).hangouts[0], MeepleWander.NO_HANGOUT)


func test_a_spot_near_a_hangout_is_on_an_empty_cell_within_two_steps() -> void:
	var hut := MeepleTestKit.place_thing(_village, Vector2i(30, 20), 2, 2)
	_wander.add_hangout(_village, hut)
	var ring := _village.grid.empty_cells_near(hut, 2)
	check_eq(ring.size(), 26, "the empty cells within two steps of a 2 by 2 thing")
	var from := GridLayout.position_of(Vector2i(30, 16))
	var used: Dictionary[Vector2i, bool] = {}
	var widest := Vector2.ZERO
	for index in 2000:
		var spot := _wander.spot_near(_village, from, hut)
		var cell := _nearest_cell(ring, spot)
		var nudge := (spot - GridLayout.position_of(cell)).abs()
		check(nudge.x <= 1.2001 and nudge.y <= 0.6001, "the spot is %s from its cell" % nudge)
		widest = widest.max(nudge)
		used[cell] = true
	check(widest.x > 1.1 and widest.y > 0.55, "the nudge goes up to 12 by 6 jam units")
	check(used.size() > 10, "the spots are spread over %d cells" % used.size())


func test_a_spot_that_can_be_reached_without_crossing_a_hangout_wins() -> void:
	var hut := MeepleTestKit.place_thing(_village, Vector2i(30, 20), 2, 2)
	_wander.add_hangout(_village, hut)
	# The meeple stands above the hut. The cells below it are behind the hut.
	var from := GridLayout.position_of(Vector2i(32, 17))
	var behind := GridLayout.position_of(Vector2i(29, 23))
	check(not _wander.is_clear(_village, from, behind), "the hut is in the way")
	check(_wander.is_clear(_village, from, GridLayout.position_of(Vector2i(31, 18))))
	for index in 500:
		var spot := _wander.spot_near(_village, from, hut)
		check(_wander.is_clear(_village, from, spot), "it picked a spot behind the hut: %s" % spot)
	# A tree is no hangout, so it is not in the way.
	var tree := MeepleTestKit.place_thing(_village, Vector2i(40, 10))
	var past_tree := GridLayout.position_of(Vector2i(42, 10))
	check_eq(_village.grid.occupant(Vector2i(40, 10)), tree)
	check(_wander.is_clear(_village, GridLayout.position_of(Vector2i(38, 10)), past_tree))


func test_the_way_to_a_spot_is_checked_at_8_points() -> void:
	# Cell (15, 20) reaches from 201 to 208 art pixels along its row.
	var wall := MeepleTestKit.place_thing(_village, Vector2i(15, 20))
	_wander.add_hangout(_village, wall)
	var from := Vector2(200.0, 100.0)
	# A way of 40 art pixels is checked every 5: the point at 205 is on the wall.
	check(not _wander.is_clear(_village, from, from + Vector2(40.0, 0.0)), "8 points find it")
	# A way of 80 is checked every 10: 210 is the first point, behind the wall.
	check(_wander.is_clear(_village, from, from + Vector2(80.0, 0.0)), "8 points step over it")


func test_only_8_points_find_a_hangout_under_the_7th_point() -> void:
	# A way of 400 art pixels along row 20. The 7th of its 8 points is 350 along.
	var from := GridLayout.position_of(Vector2i(2, 20))
	var to := from + Vector2(400.0, 0.0)
	var cell := GridLayout.cell_under(from.lerp(to, 7.0 / 8.0))
	# With 6, 7, 9 or 10 points no point is on that cell: the closest one is
	# 5.6 art pixels from the 7th of 8, and a cell is 7 wide.
	for points: int in [6, 7, 9, 10]:
		for step in range(1, points + 1):
			var point := from.lerp(to, float(step) / points)
			check(GridLayout.cell_under(point) != cell, "%d points would find it too" % points)
	check(_wander.is_clear(_village, from, to), "nothing is in the way yet")
	_wander.add_hangout(_village, MeepleTestKit.place_thing(_village, cell))
	check(not _wander.is_clear(_village, from, to), "the 7th of the 8 points is on the hangout")


func test_the_end_of_the_way_is_checked_and_its_start_is_not() -> void:
	var hut := MeepleTestKit.place_thing(_village, Vector2i(30, 20))
	_wander.add_hangout(_village, hut)
	var on_hut := GridLayout.position_of(Vector2i(30, 20))
	var away := on_hut - Vector2(80.0, 0.0)
	# The points are 10 art pixels apart, so only the last one is on the hut.
	check(not _wander.is_clear(_village, away, on_hut), "a way that ends on a hangout is blocked")
	# A meeple that stands on a cell of a hangout can walk off it.
	check(_wander.is_clear(_village, on_hut, away), "the start of the way does not count")


func test_with_no_clear_spot_the_closest_tried_spot_wins() -> void:
	# A tiny island: a hut, three empty cells in a row to its right, and a
	# wall between them and the meeple. Every way to them crosses the wall.
	var village := Village.new(64, MeepleTestKit.TICKS_PER_SECOND)
	village.add_part(Village.MEEPLES, VillageMeeples.new())
	var wander := MeepleTestKit.meeples(village).wander
	for x in range(0, 12):
		village.grid.add_cell(Vector2i(x, 0))
	var hut := MeepleTestKit.place_thing(village, Vector2i(10, 0))
	wander.add_hangout(village, hut)
	wander.add_hangout(village, MeepleTestKit.place_thing(village, Vector2i(7, 0)))
	wander.add_hangout(village, MeepleTestKit.place_thing(village, Vector2i(11, 0)))
	# The empty cells within two steps of the hut are (8, 0) and (9, 0).
	var from := GridLayout.position_of(Vector2i(2, 0))
	for index in 200:
		var spot := wander.spot_near(village, from, hut)
		check(spot.is_finite(), "it goes anyway")
		check(not wander.is_clear(village, from, spot), "the wall is in the way of every spot")
		check_eq(GridLayout.cell_under(spot), Vector2i(8, 0), "the closer of the two cells wins")
	# A hangout with no empty cell near it gives no spot.
	var lone := Village.new(64, MeepleTestKit.TICKS_PER_SECOND)
	lone.add_part(Village.MEEPLES, VillageMeeples.new())
	lone.grid.add_cell(Vector2i.ZERO)
	var only := MeepleTestKit.place_thing(lone, Vector2i.ZERO)
	check(not MeepleTestKit.meeples(lone).wander.spot_near(lone, from, only).is_finite())


func test_at_most_8_cells_near_a_hangout_are_tried() -> void:
	# The meeple stands in the middle of a thick block of hangouts, so the way
	# to every cell near the hut is blocked. The hut has 26 empty cells near it.
	var middle := Vector2i(14, 20)
	for offset in GridLayout.offsets_within(6):
		if offset != Vector2i.ZERO:
			_wander.add_hangout(_village, MeepleTestKit.place_thing(_village, middle + offset))
	var hut := MeepleTestKit.place_thing(_village, Vector2i(40, 20), 2, 2)
	_wander.add_hangout(_village, hut)
	var from := GridLayout.position_of(middle)
	var twin := RandomNumberGenerator.new()
	twin.state = _village.rng.state
	var spot := _wander.spot_near(_village, from, hut)
	check(spot.is_finite(), "it goes to the closest tried spot anyway")
	check(not _wander.is_clear(_village, from, spot), "the block is in the way")
	# Each try picks a cell and two nudges: three random numbers.
	for attempt in 8:
		twin.randi_range(0, 1)
		twin.randf_range(-1.0, 1.0)
		twin.randf_range(-1.0, 1.0)
	check_eq(_village.rng.state, twin.state, "8 tries, and not one more")


func test_a_hangout_with_no_empty_cell_near_it_sends_the_meeple_around_its_home() -> void:
	# The hut stands alone on a far island of one cell.
	var island := Vector2i(200, 200)
	_village.grid.add_cell(island)
	var hut := MeepleTestKit.place_thing(_village, island)
	_wander.add_hangout(_village, hut)
	var home := MeepleTestKit.middle()
	for index in 200:
		var spot := _wander.next_spot(_village, home, home, hut)
		var distance := spot.distance_to(home)
		check(distance >= 1.4999 and distance <= 6.0001, "a spot %s from home" % distance)


func test_every_meeple_strolls_at_the_same_speed() -> void:
	# Decided by Liam: every meeple walks at the same speed. Only the bounce
	# start differs from meeple to meeple.
	for index in 60:
		MeepleTestKit.spawn(_village, MeepleTestKit.middle() + Vector2(index * 3.0 - 90.0, 0.0))
	var strides := 0
	var moved_before := PackedFloat32Array()
	moved_before.resize(60)
	for tick in 400:
		var from := _meeples.spots.duplicate()
		_village.tick()
		for row in 60:
			var moved := _meeples.spots[row].distance_to(from[row])
			if moved > 0.0 and moved_before[row] > 0.0:
				check_near(moved_before[row], 0.15, 0.0001, "meeple %d has its own speed" % row)
				strides += 1
			moved_before[row] = moved
	check(strides > 3000, "the meeples strolled: %d full strides" % strides)


func test_a_near_hangout_is_much_more_likely_to_be_picked_than_a_far_one() -> void:
	# Weight = 1 / (1 + (distance / 100) squared). The jam game takes this one
	# distance from global_position, where one unit is one art pixel, so the
	# 100 is in art pixels. The three hangouts are 0, 98 and 196 art pixels
	# away (14 and 28 cells), so they weigh 1, about a half and about a fifth.
	var from := GridLayout.position_of(Vector2i(10, 20))
	var things: Array[int] = []
	for cell: Vector2i in [Vector2i(10, 20), Vector2i(24, 20), Vector2i(38, 20)]:
		things.append(MeepleTestKit.place_thing(_village, cell))
		_wander.add_hangout(_village, things[-1])
	var weights: Array[float] = []
	var total := 0.0
	for thing in things:
		var hundreds := from.distance_to(_village.grid.thing_position(thing)) / 100.0
		weights.append(1.0 / (1.0 + hundreds * hundreds))
		total += weights[-1]
	check_near(from.distance_to(_village.grid.thing_position(things[1])), 98.0, 0.001)
	check_near(weights[1], 0.5101, 0.0001, "98 art pixels away: about a half")
	check_near(weights[2], 0.2065, 0.0001, "196 art pixels away: about a fifth")
	var picks: Dictionary[int, int] = {things[0]: 0, things[1]: 0, things[2]: 0}
	# A twin of the village's random numbers says what each pick must be. So
	# a reach of 101 art pixels fails too, not only one that is far off.
	var twin := RandomNumberGenerator.new()
	twin.state = _village.rng.state
	var kept := PackedFloat32Array(weights)
	var wrong := 0
	for index in 20000:
		var roll := twin.randf() * total
		var want := things[2]
		for slot in 2:
			roll -= kept[slot]
			if roll <= 0.0:
				want = things[slot]
				break
		var got := _wander.pick_hangout(_village, from)
		picks[got] += 1
		if got != want:
			wrong += 1
	check_eq(wrong, 0, "picks that are not what a reach of 100 art pixels gives")
	check_near(picks[things[0]], 20000.0 * weights[0] / total, 300.0, "11,651 are expected")
	check_near(picks[things[1]], 20000.0 * weights[1] / total, 300.0, "5,943 are expected")
	check_near(picks[things[2]], 20000.0 * weights[2] / total, 300.0, "2,406 are expected")


func test_a_meeple_picks_its_hangout_again_on_15_percent_of_its_strolls() -> void:
	# Two hangouts just as far from the meeple, so a new pick is a coin toss.
	var left := MeepleTestKit.place_thing(_village, Vector2i(20, 20))
	var right := MeepleTestKit.place_thing(_village, Vector2i(30, 20))
	_wander.add_hangout(_village, left)
	_wander.add_hangout(_village, right)
	var from := GridLayout.position_of(Vector2i(25, 20))
	# A twin of the village's random numbers says what each call must answer:
	# the first number decides if it picks again, the second one which.
	var twin := RandomNumberGenerator.new()
	twin.state = _village.rng.state
	var picked_again := 0
	var wrong := 0
	for index in 20000:
		var want := left
		if twin.randf() < 0.15:
			picked_again += 1
			want = left if twin.randf() <= 0.5 else right
		if _wander.next_hangout(_village, from, left) != want:
			wrong += 1
	check_eq(wrong, 0, "calls that answered something else than the 15 percent rule")
	check_eq(_village.rng.state, twin.state, "one random number, and a second one for a new pick")
	check(picked_again > 2800 and picked_again < 3200, "%d of 20,000 picked again" % picked_again)


func test_a_meeple_picks_again_when_its_hangout_is_gone() -> void:
	var hut := MeepleTestKit.place_thing(_village, Vector2i(30, 20), 2, 2)
	var other := MeepleTestKit.place_thing(_village, Vector2i(34, 22), 2, 2)
	_wander.add_hangout(_village, hut)
	_wander.add_hangout(_village, other)
	MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	check_eq(_meeples.hangouts[0], hut)
	check(_wander.remove_hangout(hut))
	check(not _wander.remove_hangout(hut), "it is gone once")
	check_eq(_wander.hangout_count(), 1)
	for index in 50:
		check_eq(_wander.next_hangout(_village, MeepleTestKit.middle(), hut), other)
	# The meeple finds out on its next stroll, 3.5 seconds from now at the latest.
	MeepleTestKit.run(_village, 71)
	check_eq(_meeples.hangouts[0], other)
	# With no hangout left it has none, and no random number is used up.
	_wander.remove_hangout(other)
	var state := _village.rng.state
	check_eq(_wander.next_hangout(_village, MeepleTestKit.middle(), other), MeepleWander.NO_HANGOUT)
	check_eq(_village.rng.state, state)


func test_the_hangouts_left_keep_their_places_when_one_is_removed() -> void:
	var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(30, 20), Vector2i(50, 35)]
	var things: Array[int] = []
	for cell in cells:
		things.append(MeepleTestKit.place_thing(_village, cell))
		_wander.add_hangout(_village, things[-1])
	check(_wander.remove_hangout(things[0]))
	check_eq(_wander.hangout_count(), 2)
	for index: int in [1, 2]:
		var next_to := GridLayout.position_of(cells[index] + Vector2i(1, 0))
		check_eq(_wander.nearest_hangout(next_to), things[index], "the one right next to it")
	var listed := _wander.snapshot()
	var listed_things: PackedInt32Array = listed["things"]
	var listed_places: PackedVector2Array = listed["places"]
	check_eq(listed_things.size(), 2)
	for slot in listed_things.size():
		var stands := _village.grid.thing_position(listed_things[slot])
		check_eq(listed_places[slot], stands, "the list has the place of another hangout")


func test_meeples_with_a_hangout_stay_near_it() -> void:
	var hut := MeepleTestKit.place_thing(_village, Vector2i(30, 20), 2, 2)
	_wander.add_hangout(_village, hut)
	var footprint := _village.grid.thing_cells(hut)
	for index in 40:
		MeepleTestKit.spawn(_village, MeepleTestKit.middle() + Vector2(index - 20.0, -12.0))
	MeepleTestKit.run(_village, 3000)
	var strolled := 0
	for row in 40:
		if _meeples.spots[row] != _meeples.homes[row]:
			strolled += 1
		if _meeples.walking[row] == 1:
			continue
		var cell := GridLayout.cell_under(_meeples.spots[row])
		var steps := 100
		for taken in footprint:
			steps = mini(steps, GridLayout.distance(cell, taken))
		# The nudge is too small to push a spot out of its cell.
		check(steps >= 1 and steps <= 2, "a meeple stands %d steps from the hut" % steps)
	check_eq(strolled, 40, "every meeple left the spot it started on")


func _nearest_cell(cells: Array[Vector2i], spot: Vector2) -> Vector2i:
	var best := GridLayout.NO_CELL
	var best_distance := INF
	for cell in cells:
		var distance := spot.distance_squared_to(GridLayout.position_of(cell))
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best
