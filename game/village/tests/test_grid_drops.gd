extends GameTest
## Checks the drops on the ground as rows: where a drop lies, the count per
## cell and kind, claiming, and that there is no cap.

const WOOD := 1
const STONE := 2
const HAULER := 31
const OTHER_HAULER := 32

var _grid: VillageGrid
var _drops: GridDrops
var _heard: Array[String] = []


## Lays a block of 20 by 20 cells for every test.
func before_each() -> void:
	_grid = VillageGrid.new()
	for cell in GridLayout.block(Vector2i(0, 0), Vector2i(20, 20)):
		_grid.add_cell(cell)
	_drops = _grid.drops


func test_a_drop_is_a_row_with_its_kind_its_cell_and_its_spot() -> void:
	# Cell (3, 2) sits at (31, 10). The spot is 2 art pixels left of it and 1 up.
	var spot := Vector2(29.0, 9.0)
	var drop := _drops.add_at(spot, WOOD)
	check_eq(drop, 0, "the first drop is row 0")
	check_eq(_drops.kind_of(drop), WOOD)
	check_eq(_drops.cell_of(drop), Vector2i(3, 2))
	check_eq(_drops.spot_of(drop), spot, "it lies where it landed, not on the cell middle")
	check(_drops.spot_of(drop) != GridLayout.position_of(Vector2i(3, 2)), "not the cell position")
	check_eq(_drops.claimer_of(drop), GridDrops.NOBODY)
	check(_drops.has(drop), "the row holds a drop")


func test_two_drops_on_one_cell_keep_their_own_spots() -> void:
	var first := _drops.add_at(Vector2(29.0, 9.0), WOOD)
	var second := _drops.add_at(Vector2(33.0, 11.5), WOOD)
	check_eq(_drops.cell_of(first), Vector2i(3, 2))
	check_eq(_drops.cell_of(second), Vector2i(3, 2))
	check_eq(_drops.spot_of(first), Vector2(29.0, 9.0))
	check_eq(_drops.spot_of(second), Vector2(33.0, 11.5))


func test_each_cell_keeps_a_count_per_kind() -> void:
	_drops.add_at(Vector2(29.0, 9.0), WOOD)
	_drops.add_at(Vector2(33.0, 11.5), WOOD)
	_drops.add_at(Vector2(31.0, 10.0), STONE)
	_drops.add_at(GridLayout.position_of(Vector2i(4, 2)), WOOD)
	check_eq(_drops.count_at(Vector2i(3, 2), WOOD), 2)
	check_eq(_drops.count_at(Vector2i(3, 2), STONE), 1)
	check_eq(_drops.count_at(Vector2i(4, 2), WOOD), 1)
	check_eq(_drops.count_at(Vector2i(4, 2), STONE), 0)
	check_eq(_drops.at(Vector2i(3, 2)), {WOOD: 2, STONE: 1})
	check_eq(_drops.total(WOOD), 3)
	check_eq(_drops.total(STONE), 1)
	check_eq(_drops.loose(WOOD), 3)


func test_there_is_no_cap_on_a_cell_or_on_the_ground() -> void:
	var cell := Vector2i(5, 5)
	for i in 500:
		_drops.add_at(GridLayout.position_of(cell), WOOD)
	check_eq(_drops.count_at(cell, WOOD), 500)
	for other in GridLayout.block(Vector2i(0, 0), Vector2i(20, 20)):
		_drops.add_at(GridLayout.position_of(other), STONE)
	check_eq(_drops.total(STONE), 400)
	check_eq(_drops.total(WOOD), 500)


func test_a_drop_needs_a_cell_under_its_spot_and_a_kind_from_1_to_255() -> void:
	check_eq(_drops.add_at(Vector2(-500.0, -500.0), WOOD), GridDrops.NO_DROP)
	check_eq(_drops.add_at(Vector2(31.0, 10.0), 0), GridDrops.NO_DROP)
	check_eq(_drops.add_at(Vector2(31.0, 10.0), 256), GridDrops.NO_DROP)
	check_eq(_drops.add_at(Vector2(31.0, 10.0), 255), 0)
	check_eq(_drops.total(WOOD), 0)
	check(not _drops.is_ground(Vector2(-500.0, -500.0)), "no cell there")
	check(_drops.is_ground(Vector2(31.0, 10.0)), "a cell is there")


func test_removing_a_drop_takes_it_off_its_cell_and_frees_its_row() -> void:
	var first := _drops.add_at(Vector2(29.0, 9.0), WOOD)
	var second := _drops.add_at(Vector2(33.0, 11.5), WOOD)
	check(_drops.remove(first), "a loose drop can be taken")
	check(not _drops.has(first), "its row is free")
	check_eq(_drops.kind_of(first), GridDrops.NO_KIND)
	check_eq(_drops.count_at(Vector2i(3, 2), WOOD), 1)
	check_eq(_drops.total(WOOD), 1)
	check(not _drops.remove(first), "it cannot be taken twice")
	check(not _drops.remove(77), "a row that was never used is no drop")
	check(_drops.has(second), "the other drop is still there")
	var third := _drops.add_at(Vector2(40.0, 10.0), STONE)
	check_eq(third, first, "the free row is used again")
	check_eq(_drops.kind_of(third), STONE)
	check_eq(_drops.size(), 2)


func test_a_claimed_drop_still_lies_there_but_is_not_loose() -> void:
	var drop := _drops.add_at(Vector2(29.0, 9.0), WOOD)
	check(_drops.claim(drop, HAULER), "a loose drop can be claimed")
	check_eq(_drops.claimer_of(drop), HAULER)
	check_eq(_drops.count_at(Vector2i(3, 2), WOOD), 1)
	check(_drops.has_any(Vector2i(3, 2)), "it still lies on the cell")
	check_eq(_drops.total(WOOD), 1)
	check_eq(_drops.loose(WOOD), 0)
	check(not _drops.claim(drop, OTHER_HAULER), "it cannot be claimed twice")
	check_eq(_drops.claimer_of(drop), HAULER)
	check(not _drops.claim(drop, HAULER), "not even by the same one again")
	check(_drops.unclaim(drop), "the claim can be given back")
	check_eq(_drops.loose(WOOD), 1)
	check(not _drops.unclaim(drop), "a loose drop has no claim to give back")
	check(not _drops.claim(drop, 0), "id 0 means nobody")


func test_only_the_claimer_can_take_a_claimed_drop() -> void:
	var drop := _drops.add_at(Vector2(29.0, 9.0), WOOD)
	_drops.claim(drop, HAULER)
	check(not _drops.remove(drop), "nobody else can take it")
	check(not _drops.remove(drop, OTHER_HAULER), "another hauler cannot take it")
	check_eq(_drops.total(WOOD), 1)
	check(_drops.remove(drop, HAULER), "its claimer can")
	check_eq(_drops.total(WOOD), 0)
	check(not _drops.has_any(Vector2i(3, 2)), "nothing lies on the cell any more")


func test_take_leaves_the_claimed_drops_of_a_cell() -> void:
	var cell := Vector2i(3, 2)
	_drops.add(cell, WOOD, 3)
	var newest := _drops.add_at(GridLayout.position_of(cell), WOOD)
	_drops.claim(newest, HAULER)
	check_eq(_drops.take(cell, WOOD, 99), 3)
	check_eq(_drops.count_at(cell, WOOD), 1)
	check(_drops.has(newest), "the claimed drop was left")


func test_the_ground_says_when_a_drop_comes_and_goes() -> void:
	_drops.added.connect(_hear.bind("added"))
	_drops.removed.connect(_hear.bind("removed"))
	var drop := _drops.add_at(Vector2(29.0, 9.0), STONE)
	_drops.claim(drop, HAULER)
	_drops.unclaim(drop)
	_drops.remove(drop)
	_drops.add_at(Vector2(-500.0, -500.0), STONE)
	check_eq(_heard, ["added 0 kind 2", "removed 0 kind 2"] as Array[String])


func test_the_same_steps_give_the_same_snapshot() -> void:
	var other := VillageGrid.new()
	for cell in GridLayout.block(Vector2i(0, 0), Vector2i(20, 20)):
		other.add_cell(cell)
	for grid: VillageGrid in [_grid, other]:
		var first := grid.drops.add_at(Vector2(29.0, 9.0), WOOD)
		grid.drops.add_at(Vector2(33.0, 11.5), STONE)
		grid.drops.claim(first, HAULER)
		grid.drops.add_at(Vector2(60.0, 40.0), WOOD)
	check_eq(_grid.snapshot(), other.snapshot())
	other.drops.unclaim(0)
	check(_grid.snapshot() != other.snapshot(), "a claim shows in the snapshot")
	other.drops.claim(0, HAULER)
	other.drops.remove(1)
	check(_grid.snapshot() != other.snapshot(), "a taken drop shows in the snapshot")


func test_drops_work_below_zero_and_across_chunk_edges() -> void:
	for cell in GridLayout.block(Vector2i(-20, -20), Vector2i(20, 20)):
		_grid.add_cell(cell)
	var spot := GridLayout.position_of(Vector2i(-17, -1)) + Vector2(2.0, -1.0)
	var drop := _drops.add_at(spot, WOOD)
	check_eq(_drops.cell_of(drop), Vector2i(-17, -1))
	check_eq(_drops.count_at(Vector2i(-17, -1), WOOD), 1)
	check_eq(_drops.count_at(Vector2i(-1, -1), WOOD), 0)
	check_eq(_drops.count_at(Vector2i(15, 15), WOOD), 0)


func _hear(drop: int, kind: int, what: String) -> void:
	_heard.append("%s %d kind %d" % [what, drop, kind])
