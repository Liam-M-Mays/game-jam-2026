extends GameTest
## Checks "the closest loose drop of a kind", and how many drops one lookup
## looks at when 1,000 and when 100,000 drops lie around.

const WOOD := 1
const STONE := 2
const HAULER := 31
## The most drops one lookup may look at. Issue #63 asks for under 200.
## Liam can change this number.
const MOST_LOOKED_AT := 200
## The most cells one lookup may read on the way. This guard is not from the
## issue: it catches a lookup that starts to walk the whole map.
const MOST_CELLS_READ := 2000
## A round map this many steps wide has 99,919 cells: the world size of the
## dev settings, about 100,000.
const WORLD_STEPS := 182
const WORLD_CELLS := 99919
## How many lookups each big test makes, and how many of them are also worked
## out the slow way, by looking at every drop.
const LOOKUPS := 300
const SLOW_CHECKS := 12
## How far apart two spots on one cell can be: the corner to corner of a cell
## of 7 by 5 art pixels.
const CELL_CORNER_TO_CORNER := 8.61

var _grid: VillageGrid
var _drops: GridDrops
var _rng := RandomNumberGenerator.new()
var _cells: Array[Vector2i] = []


## A fixed seed for every test.
func before_each() -> void:
	_rng.seed = 63
	_grid = VillageGrid.new()
	_drops = _grid.drops


func test_the_closest_drop_is_found_by_its_spot_not_by_its_cell() -> void:
	_lay_block(Vector2i(0, 0), Vector2i(20, 20))
	# Both drops lie on cells next to the point. The one on the far cell lies
	# at the near edge of its cell, so it is the closer one.
	var near_cell_far_spot := _drops.add_at(Vector2(33.9, 10.0), WOOD)
	var far_cell_near_spot := _drops.add_at(Vector2(41.6, 10.0), WOOD)
	check_eq(_drops.cell_of(near_cell_far_spot), Vector2i(3, 2))
	check_eq(_drops.cell_of(far_cell_near_spot), Vector2i(5, 2))
	check_eq(_drops.closest(WOOD, Vector2(38.0, 10.0)), far_cell_near_spot)
	check_eq(_drops.closest(WOOD, Vector2(37.0, 10.0)), near_cell_far_spot)


func test_no_drop_of_the_kind_gives_no_drop() -> void:
	_lay_block(Vector2i(0, 0), Vector2i(20, 20))
	check_eq(_drops.closest(WOOD, Vector2(30.0, 10.0)), GridDrops.NO_DROP)
	_drops.add_at(Vector2(30.0, 10.0), STONE)
	check_eq(_drops.closest(WOOD, Vector2(30.0, 10.0)), GridDrops.NO_DROP)
	check_eq(_drops.looked_at, 0)


func test_only_the_kind_that_was_asked_for_is_found() -> void:
	_lay_block(Vector2i(0, 0), Vector2i(20, 20))
	var stone := _drops.add_at(Vector2(30.0, 10.0), STONE)
	var wood := _drops.add_at(Vector2(90.0, 60.0), WOOD)
	check_eq(_drops.closest(WOOD, Vector2(30.0, 10.0)), wood)
	check_eq(_drops.closest(STONE, Vector2(90.0, 60.0)), stone)


func test_a_claimed_drop_is_not_found_until_it_is_loose_again() -> void:
	_lay_block(Vector2i(0, 0), Vector2i(20, 20))
	var near := _drops.add_at(Vector2(30.0, 10.0), WOOD)
	var far := _drops.add_at(Vector2(90.0, 60.0), WOOD)
	_drops.claim(near, HAULER)
	check_eq(_drops.closest(WOOD, Vector2(30.0, 10.0)), far)
	_drops.claim(far, HAULER)
	check_eq(_drops.closest(WOOD, Vector2(30.0, 10.0)), GridDrops.NO_DROP)
	_drops.unclaim(near)
	check_eq(_drops.closest(WOOD, Vector2(30.0, 10.0)), near)


func test_a_taken_drop_is_not_found() -> void:
	_lay_block(Vector2i(0, 0), Vector2i(20, 20))
	var near := _drops.add_at(Vector2(30.0, 10.0), WOOD)
	var far := _drops.add_at(Vector2(90.0, 60.0), WOOD)
	_drops.remove(near)
	check_eq(_drops.closest(WOOD, Vector2(30.0, 10.0)), far)


func test_every_lookup_gives_the_same_drop_as_looking_at_all_of_them() -> void:
	_lay_block(Vector2i(-24, -24), Vector2i(48, 48))
	_scatter(1500, WOOD)
	_scatter(1500, STONE)
	for i in 400:
		_drops.claim(_rng.randi_range(0, 2999), HAULER)
	check(_deepest_stack() <= GridDrops.MOST_LOOKS_PER_CELL, "no cell holds a deep stack here")
	var wrong := 0
	for i in 600:
		var kind := WOOD if i % 2 == 0 else STONE
		# Every fourth point is far outside the map.
		var reach := 900.0 if i % 4 == 3 else 260.0
		var point := Vector2(_rng.randf_range(-reach, reach), _rng.randf_range(-reach, reach))
		var found := _drops.closest(kind, point)
		var slow := _closest_the_slow_way(kind, point)
		if found == GridDrops.NO_DROP or _distance(found, point) != _distance(slow, point):
			wrong += 1
	check_eq(wrong, 0, "lookups that did not give the closest drop")


func test_one_far_drop_is_found_and_is_the_only_one_looked_at() -> void:
	_lay_world()
	_scatter(20000, STONE)
	var far_cell := Vector2i(150, -100)
	var wood := _drops.add_at(GridLayout.position_of(far_cell), WOOD)
	check_eq(_drops.closest(WOOD, GridLayout.position_of(Vector2i(-150, 100))), wood)
	check_eq(_drops.looked_at, 1)
	print("CLOSEST_LOOKS one far drop: cells read %d" % _drops.cells_read)


func test_a_lookup_among_1000_drops_looks_at_fewer_than_200() -> void:
	_lay_world()
	_scatter(1000, WOOD)
	check_eq(_drops.loose(WOOD), 1000)
	_check_the_lookups("1,000 drops")


func test_a_lookup_among_100000_drops_looks_at_fewer_than_200() -> void:
	_lay_world()
	_scatter(100000, WOOD)
	check_eq(_drops.loose(WOOD), 100000)
	_check_the_lookups("100,000 drops")


func test_a_lookup_next_to_a_heap_of_100000_drops_looks_at_fewer_than_200() -> void:
	_lay_world()
	# Every drop lies on a block of 6 by 6 cells: 2,777 or 2,778 on each cell.
	var heap := GridLayout.block(Vector2i(-3, -3), Vector2i(6, 6))
	for i in 100000:
		_drops.add_at(_spot_on(heap[i % heap.size()]), WOOD)
	check_eq(_drops.count_at(heap[0], WOOD), 2778)
	check_eq(_drops.count_at(heap[35], WOOD), 2777)
	var most := 0
	for i in LOOKUPS:
		# Points in the heap, around it and far from it.
		var reach := 30.0 if i % 3 == 0 else (120.0 if i % 3 == 1 else 1500.0)
		var point := Vector2(_rng.randf_range(-reach, reach), _rng.randf_range(-reach, reach))
		var found := _drops.closest(WOOD, point)
		most = maxi(most, _drops.looked_at)
		if i < SLOW_CHECKS:
			var slow := _closest_the_slow_way(WOOD, point)
			var off := sqrt(_distance(found, point)) - sqrt(_distance(slow, point))
			check(off <= CELL_CORNER_TO_CORNER, "the pick is off by less than one cell")
	check(most >= GridDrops.MOST_LOOKS_PER_CELL, "the heap was looked at")
	check(most < MOST_LOOKED_AT, "looked at %d drops, the cap is %d" % [most, MOST_LOOKED_AT])
	print("CLOSEST_LOOKS a heap of 100,000 drops on 36 cells: most looked at %d" % most)


func test_on_one_cell_only_the_newest_drops_are_looked_at() -> void:
	_lay_block(Vector2i(0, 0), Vector2i(20, 20))
	var cell := Vector2i(3, 2)
	for i in 30:
		_drops.add_at(_spot_on(cell), WOOD)
	var found := _drops.closest(WOOD, GridLayout.position_of(cell))
	check_eq(_drops.looked_at, GridDrops.MOST_LOOKS_PER_CELL)
	check(found >= 30 - GridDrops.MOST_LOOKS_PER_CELL, "one of the newest drops was picked")
	check_eq(_drops.cell_of(found), cell)


## Makes [constant LOOKUPS] lookups from random points of the world. Every
## one has to find a drop and look at fewer than [constant MOST_LOOKED_AT].
## The first few are also checked against looking at every drop.
func _check_the_lookups(label: String) -> void:
	var most := 0
	var sum := 0
	var none := 0
	var wrong := 0
	var most_cells := 0
	var spent := 0
	for i in LOOKUPS:
		var point := _spot_on(_cells[_rng.randi_range(0, _cells.size() - 1)])
		var started := Time.get_ticks_usec()
		var found := _drops.closest(WOOD, point)
		spent += Time.get_ticks_usec() - started
		most = maxi(most, _drops.looked_at)
		most_cells = maxi(most_cells, _drops.cells_read)
		sum += _drops.looked_at
		if found == GridDrops.NO_DROP or _drops.looked_at < 1:
			none += 1
		elif i < SLOW_CHECKS:
			var slow := _closest_the_slow_way(WOOD, point)
			if _distance(found, point) != _distance(slow, point):
				wrong += 1
	check_eq(none, 0, "lookups that found no drop")
	check_eq(wrong, 0, "lookups that did not give the closest drop")
	check(most < MOST_LOOKED_AT, "looked at %d drops, the cap is %d" % [most, MOST_LOOKED_AT])
	check(most_cells < MOST_CELLS_READ, "read %d cells, the cap is %d" % [most_cells, MOST_CELLS_READ])
	var mean := float(sum) / LOOKUPS
	# The time is only printed. It depends on what else the machine is doing.
	print(
		"CLOSEST_LOOKS %s: most looked at %d, on average %.1f, most cells read %d, %.1f usec a lookup"
		% [label, most, mean, most_cells, float(spent) / LOOKUPS]
	)


func _lay_block(origin: Vector2i, size: Vector2i) -> void:
	_cells = GridLayout.block(origin, size)
	for cell in _cells:
		_grid.add_cell(cell)


## Lays the round world of about 100,000 cells.
func _lay_world() -> void:
	_cells = GridLayout.offsets_within(WORLD_STEPS)
	for cell in _cells:
		_grid.add_cell(cell)
	check_eq(_grid.cell_count(), WORLD_CELLS)


## Lays [param count] drops of [param kind] on random spots of the map.
func _scatter(count: int, kind: int) -> void:
	for i in count:
		_drops.add_at(_spot_on(_cells[_rng.randi_range(0, _cells.size() - 1)]), kind)


## A random spot on [param cell].
func _spot_on(cell: Vector2i) -> Vector2:
	var middle := GridLayout.position_of(cell) + GridLayout.CELL_MIDDLE
	return middle + Vector2(_rng.randf_range(-3.4, 3.4), _rng.randf_range(-2.4, 2.4))


func _deepest_stack() -> int:
	var deepest := 0
	for cell in _cells:
		deepest = maxi(deepest, maxi(_drops.count_at(cell, WOOD), _drops.count_at(cell, STONE)))
	return deepest


func _closest_the_slow_way(kind: int, point: Vector2) -> int:
	var best := GridDrops.NO_DROP
	var best_distance := INF
	for drop in _drops.size():
		if _drops.kind_of(drop) != kind or _drops.claimer_of(drop) != GridDrops.NOBODY:
			continue
		var distance := point.distance_squared_to(_drops.spot_of(drop))
		if distance < best_distance:
			best_distance = distance
			best = drop
	return best


func _distance(drop: int, point: Vector2) -> float:
	return point.distance_squared_to(_drops.spot_of(drop))
