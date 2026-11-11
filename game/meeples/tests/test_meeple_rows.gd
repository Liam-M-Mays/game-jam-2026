extends GameTest
## Checks the meeple rows: adding and taking out, that no row is left behind,
## that a waiting meeple costs nothing, what a meeple carries, and that a
## closed village lets go of its meeples.

const WOOD := 1
const STONE := 2

var _village: Village
var _meeples: VillageMeeples
var _removed: Array[Array] = []
var _changed: Array[int] = []
var _died := 0
var _taken_out := 0


func before_each() -> void:
	_village = MeepleTestKit.village(64)
	_meeples = MeepleTestKit.meeples(_village)


func test_a_new_meeple_gets_a_row_an_id_and_its_own_colour() -> void:
	var spot := MeepleTestKit.middle()
	var first := MeepleTestKit.spawn(_village, spot)
	var second := MeepleTestKit.spawn(_village, spot + Vector2(9.0, 4.0))
	check_eq(_meeples.count(), 2)
	check(first != second and first > 0 and second > 0, "each meeple has its own id above zero")
	check_eq(_meeples.row_of(first), 0)
	check_eq(_meeples.row_of(second), 1)
	check_eq(_meeples.ids[1], second)
	check_eq(_meeples.spots[1], spot + Vector2(9.0, 4.0))
	check_eq(_meeples.before[1], spot + Vector2(9.0, 4.0))
	check_eq(int(_meeples.states[1]), VillageMeeples.IDLE)
	check_eq(int(_meeples.walking[1]), 0)
	check_eq(_meeples.fades[1], 1.0)
	check_eq(_meeples.topples[1], 0.0)
	check(_meeples.hues[0] != _meeples.hues[1], "two meeples have two shirt colours")
	check(_meeples.has_meeple(first) and not _meeples.has_meeple(9999))
	check_eq(_meeples.row_of(9999), VillageMeeples.NO_ROW)


func test_every_meeple_starts_its_bounce_at_its_own_point() -> void:
	var seen: Dictionary[float, bool] = {}
	for index in 500:
		var row := _meeples.row_of(MeepleTestKit.spawn(_village, MeepleTestKit.middle()))
		var bounce := _meeples.bounces[row]
		check(bounce >= 0.0 and bounce < 1.0, "a bounce start is from 0 to 1")
		check(_meeples.hues[row] >= 0.0 and _meeples.hues[row] < 1.0, "a hue is from 0 to 1")
		seen[bounce] = true
	check(seen.size() >= 495, "500 meeples have %d bounce starts" % seen.size())


func test_a_waiting_meeple_costs_nothing_per_tick() -> void:
	var waiting: Array[int] = []
	for index in 500:
		var spot := MeepleTestKit.middle() + Vector2(index % 25, index / 25.0)
		waiting.append(MeepleTestKit.spawn(_village, spot))
	# The first pause is at least one second, so nobody wakes in 19 ticks.
	MeepleTestKit.run(_village, 9)
	check_eq(_meeples.steps, 0, "500 waiting meeples, 9 ticks, no meeple was stepped")
	check_eq(_village.timers.steps, 0, "no timer was looked at")
	check_eq(_meeples.walkers.size(), 0)
	# Three of them walk. Each tick steps those three and nobody else.
	for index in 3:
		_meeples.walk_to(_village, waiting[index], MeepleTestKit.middle() + Vector2(90.0, 0.0))
	MeepleTestKit.run(_village, 10)
	check_eq(_meeples.steps, 30, "3 walking meeples, 10 ticks")
	check_eq(_village.timers.steps, 0)
	check_eq(_village.timers.sleeping(), 497, "the other 497 sleep on a timer")


func test_a_taken_out_meeple_leaves_no_gap() -> void:
	_meeples.meeple_removed.connect(_note_removed)
	var spot := MeepleTestKit.middle()
	var first := MeepleTestKit.spawn(_village, spot)
	var second := MeepleTestKit.spawn(_village, spot + Vector2(5.0, 0.0))
	var third := MeepleTestKit.spawn(_village, spot + Vector2(10.0, 0.0))
	_meeples.carry(third, STONE, 2)
	MeepleTestKit.hold(_village, second)
	MeepleTestKit.hold(_village, third)
	var third_hue := _meeples.hues[2]
	var third_bounce := _meeples.bounces[2]
	MeepleTestKit.kill(_village, first)
	MeepleTestKit.run(_village, 41)
	check_eq(_meeples.count(), 2)
	check(not _meeples.has_meeple(first), "the dead meeple is gone")
	# The last row moved into the free row, with everything it had.
	check_eq(_meeples.row_of(third), 0)
	check_eq(_meeples.row_of(second), 1)
	check_eq(_meeples.ids[0], third)
	check_eq(_meeples.spots[0], spot + Vector2(10.0, 0.0))
	check_eq(_meeples.hues[0], third_hue)
	check_eq(_meeples.bounces[0], third_bounce)
	check_eq(_meeples.load_kinds[0], STONE)
	check_eq(int(_meeples.load_counts[0]), 2)
	check_eq(_meeples.fades[0], 1.0)
	check_eq(_removed, [[first, 0, 2]])


func test_ten_thousand_spawns_and_deaths_leave_no_row_behind() -> void:
	_meeples.meeple_died.connect(_count_died)
	_meeples.meeple_removed.connect(_count_taken_out)
	var rng := RandomNumberGenerator.new()
	rng.seed = 64
	var alive: Array[int] = []
	var spawned := 0
	while spawned < 10000:
		for index in 250:
			var spot := MeepleTestKit.middle() + Vector2(rng.randf_range(-60, 60), rng.randf_range(-40, 40))
			alive.append(MeepleTestKit.spawn(_village, spot))
			spawned += 1
		# Some get a job, so walking, waiting and dying meeples are mixed.
		for index in 60:
			var worker := alive[rng.randi_range(0, alive.size() - 1)]
			_meeples.walk_to(_village, worker, MeepleTestKit.middle())
		MeepleTestKit.run(_village, 6)
		for index in 240:
			var at := rng.randi_range(0, alive.size() - 1)
			MeepleTestKit.kill(_village, alive[at])
			alive[at] = alive[alive.size() - 1]
			alive.pop_back()
		MeepleTestKit.run(_village, 6)
		_check_rows_are_packed()
	for meeple in alive:
		MeepleTestKit.kill(_village, meeple)
	MeepleTestKit.run(_village, 41)
	check_eq(spawned, 10000)
	check_eq(_died, 10000, "every meeple died once")
	check_eq(_taken_out, 10000, "every meeple was taken out once")
	check_eq(_meeples.count(), 0)
	var sizes := _meeples.sizes()
	check_eq(sizes.size(), 27, "23 columns, two lists, the lookup and the arrivals")
	for part: String in sizes:
		check_eq(sizes[part], 0, "left behind in %s" % part)
	check_eq(_village.timers.sleeping(), 0, "no wake-up timer is left")


func test_killing_a_meeple_twice_is_the_same_as_once() -> void:
	_meeples.meeple_died.connect(_count_died)
	var meeple := MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	check(MeepleTestKit.kill(_village, meeple), "the first kill is done")
	MeepleTestKit.run(_village, 5)
	var topple := _meeples.topples[0]
	check(not MeepleTestKit.kill(_village, meeple), "the second kill is refused")
	check_eq(_died, 1)
	check_eq(_meeples.dying.size(), 1)
	check_eq(_meeples.topples[0], topple)
	check(not MeepleTestKit.kill(_village, 9999), "nobody to kill")


func test_a_meeple_carries_one_or_two_pieces_of_a_kind() -> void:
	_meeples.meeple_changed.connect(_note_changed)
	var meeple := MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	check_eq(_meeples.load_kinds[0], VillageMeeples.NO_LOAD)
	check_eq(int(_meeples.load_counts[0]), 0)
	check(_meeples.carry(meeple, WOOD, 1))
	check_eq(_meeples.load_kinds[0], WOOD)
	check_eq(int(_meeples.load_counts[0]), 1)
	check(_meeples.carry(meeple, STONE, 2))
	check_eq(_meeples.load_kinds[0], STONE)
	check_eq(int(_meeples.load_counts[0]), 2)
	check_eq(_changed, [0, 0], "the picture is told about each change")
	# The same load again is no change.
	_meeples.carry(meeple, STONE, 2)
	check_eq(_changed.size(), 2)
	# Empty hands have no kind.
	_meeples.carry(meeple, STONE, 0)
	check_eq(_meeples.load_kinds[0], VillageMeeples.NO_LOAD)
	check_eq(int(_meeples.load_counts[0]), 0)
	check(not _meeples.carry(9999, WOOD, 1), "nobody to carry it")


func test_the_snapshot_holds_every_column() -> void:
	for index in 7:
		MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	var snapshot := _meeples.snapshot()
	var columns: Dictionary = snapshot["columns"]
	check_eq(columns.size(), 23)
	for column_name: String in columns:
		check_eq(columns[column_name].size(), 7, column_name)
	check_eq(columns["ids"], _meeples.ids)
	# The snapshot is a copy: the village moves on and the snapshot does not.
	MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	check_eq(columns["ids"].size(), 7)
	check_eq(_village.snapshot()["parts"][Village.MEEPLES]["columns"]["ids"].size(), 8)


func test_a_closed_village_lets_go_of_its_meeples() -> void:
	var gone: Array[bool] = [false]
	_meeples.closed.connect(func() -> void: gone[0] = true)
	var thing := MeepleTestKit.place_thing(_village, Vector2i(30, 20))
	_meeples.wander.add_hangout(_village, thing)
	for index in 50:
		MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	MeepleTestKit.kill(_village, _meeples.ids[3])
	MeepleTestKit.run(_village, 30)
	var part: WeakRef = weakref(_meeples)
	_village.close()
	check(gone[0], "the part said that it closed")
	check_eq(_meeples.count(), 0)
	for part_name: String in _meeples.sizes():
		check_eq(_meeples.sizes()[part_name], 0, "still held in %s" % part_name)
	check_eq(_meeples.wander.hangout_count(), 0)
	check_eq(_village.timers.sleeping(), 0)
	check_eq(_meeples.spawn(_village, MeepleTestKit.middle()), VillageMeeples.NO_MEEPLE)
	check_eq(_meeples.count(), 0, "a closed village takes no meeple")
	# Nothing holds on to the part once the test lets go of it.
	_meeples = null
	check(part.get_ref() == null, "the meeples part is freed with its village")


func _check_rows_are_packed() -> void:
	var sizes := _meeples.sizes()
	var count := _meeples.count()
	var packed: bool = sizes["row_of"] == count
	for column_name: String in _meeples.snapshot()["columns"]:
		packed = packed and sizes[column_name] == count
	for row in count:
		packed = packed and _meeples.row_of(_meeples.ids[row]) == row
	for slot in _meeples.walkers.size():
		packed = packed and _meeples.walkers[slot] < count
	for slot in _meeples.dying.size():
		var row := _meeples.dying[slot]
		packed = packed and row < count and _meeples.states[row] == VillageMeeples.DYING
	check(packed, "every column has one entry per meeple and every list points at a row")


func _note_removed(meeple: int, row: int, moved_from: int) -> void:
	_removed.append([meeple, row, moved_from])


func _note_changed(row: int) -> void:
	_changed.append(row)


func _count_died(_meeple: int, _spot: Vector2) -> void:
	_died += 1


func _count_taken_out(_meeple: int, _row: int, _moved_from: int) -> void:
	_taken_out += 1
