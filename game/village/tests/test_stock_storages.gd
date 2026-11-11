extends GameTest
## Checks the storages as plain counts: what a storage holds, what
## [method StockStorages.change] refuses, and what the snapshot holds.

const WOOD := 1
const STONE := 2
const PILE := 501
const OTHER_PILE := 502
const SPOT := Vector2(31.0, 10.0)
const OTHER_SPOT := Vector2(101.0, 10.0)

var _storages: StockStorages


## One wood pile for 3 units.
func before_each() -> void:
	_storages = StockStorages.new()
	_storages.add(PILE, WOOD, 3, SPOT)


func test_a_new_storage_is_empty_and_has_room() -> void:
	check(_storages.has(PILE), "the pile is there")
	check_eq(_storages.kind_of(PILE), WOOD)
	check_eq(_storages.spot_of(PILE), SPOT)
	check_eq(_storages.capacity_of(PILE), 3)
	check_eq(_storages.stored_in(PILE), 0)
	check_eq(_storages.free_in(PILE), 0)
	check_eq(_storages.room_in(PILE), 3)
	check_eq(_storages.capacity_total(WOOD), 3)
	check_eq(_storages.ids(), PackedInt32Array([PILE]))


func test_a_storage_needs_a_free_id_a_kind_and_a_capacity() -> void:
	check(not _storages.add(PILE, WOOD, 5, SPOT), "the id is taken")
	check(not _storages.add(0, WOOD, 5, SPOT), "id 0 means no storage")
	check(not _storages.add(OTHER_PILE, 0, 5, SPOT), "kind 0 is no kind")
	check(not _storages.add(OTHER_PILE, WOOD, -1, SPOT), "a capacity below zero")
	check(not _storages.has(OTHER_PILE), "none of them was added")
	check_eq(_storages.capacity_total(WOOD), 3)
	check_eq(_storages.room_in(OTHER_PILE), 0, "a storage that is not there has no room")


func test_change_moves_the_three_counts() -> void:
	check(_storages.change(PILE, 2, 1, 1), "2 units in it, 1 of them claimed, 1 more coming")
	check_eq(_storages.stored_in(PILE), 2)
	check_eq(_storages.free_in(PILE), 1)
	check_eq(_storages.room_in(PILE), 0)
	check_eq(_storages.stored_total(WOOD), 2)
	check_eq(_storages.free_total(WOOD), 1)
	check(_storages.change(PILE, -1, -1, 0), "the claimed unit is taken out")
	check_eq(_storages.stored_in(PILE), 1)
	check_eq(_storages.free_in(PILE), 1)
	check_eq(_storages.room_in(PILE), 1)


func test_no_count_can_go_below_zero() -> void:
	_storages.change(PILE, 1, 0, 0)
	check(not _storages.change(PILE, -2, 0, 0), "more units taken out than are there")
	check(not _storages.change(PILE, 0, -1, 0), "a claim given back that was never made")
	check(not _storages.change(PILE, 0, 0, -1), "a unit arrives that was never on its way")
	_check_the_pile_is_as_it_was()


func test_more_cannot_be_claimed_than_is_there() -> void:
	_storages.change(PILE, 1, 0, 0)
	check(not _storages.change(PILE, 0, 2, 0), "two claims on one unit")
	check(not _storages.change(PILE, -1, 1, 0), "a claim on a unit that is taken out")
	_check_the_pile_is_as_it_was()


func test_more_cannot_be_there_and_coming_than_fits() -> void:
	_storages.change(PILE, 1, 0, 0)
	check(not _storages.change(PILE, 3, 0, 0), "4 units in a pile for 3")
	check(not _storages.change(PILE, 0, 0, 3), "1 there and 3 coming")
	check(not _storages.change(PILE, 1, 0, 2), "2 there and 2 coming")
	_check_the_pile_is_as_it_was()
	check(_storages.change(PILE, 0, 0, 2), "1 there and 2 coming fits")
	check_eq(_storages.room_in(PILE), 0)


func test_a_storage_that_is_not_there_cannot_be_changed() -> void:
	check(not _storages.change(OTHER_PILE, 1, 0, 0), "there is no such storage")
	check_eq(_storages.stored_total(WOOD), 0)


func test_the_closest_storage_with_a_free_unit_is_found() -> void:
	_storages.add(OTHER_PILE, WOOD, 3, OTHER_SPOT)
	check_eq(_storages.closest_free(WOOD, SPOT), StockStorages.NO_STORAGE, "both are empty")
	_storages.change(PILE, 1, 0, 0)
	_storages.change(OTHER_PILE, 1, 0, 0)
	check_eq(_storages.closest_free(WOOD, SPOT), PILE)
	check_eq(_storages.closest_free(WOOD, OTHER_SPOT), OTHER_PILE)
	check_eq(_storages.closest_free(STONE, SPOT), StockStorages.NO_STORAGE, "another kind")
	_storages.change(PILE, 0, 1, 0)
	check_eq(_storages.closest_free(WOOD, SPOT), OTHER_PILE, "a claimed unit is not free")


func test_the_snapshot_holds_every_count_of_every_storage() -> void:
	_storages.add(OTHER_PILE, STONE, 8, OTHER_SPOT)
	_storages.change(PILE, 2, 1, 1)
	var shot := _storages.snapshot()
	check_eq(shot.keys(), ["kinds", "spots", "capacities", "stored", "claimed", "coming"])
	check_eq(shot.get("kinds"), {PILE: WOOD, OTHER_PILE: STONE})
	check_eq(shot.get("spots"), {PILE: SPOT, OTHER_PILE: OTHER_SPOT})
	check_eq(shot.get("capacities"), {PILE: 3, OTHER_PILE: 8})
	check_eq(shot.get("stored"), {PILE: 2, OTHER_PILE: 0})
	check_eq(shot.get("claimed"), {PILE: 1, OTHER_PILE: 0})
	check_eq(shot.get("coming"), {PILE: 1, OTHER_PILE: 0})
	# A snapshot is a copy: changing it does not change the storages.
	shot["stored"][PILE] = 99
	check_eq(_storages.stored_in(PILE), 2)


func test_clear_forgets_every_storage() -> void:
	_storages.change(PILE, 2, 1, 0)
	_storages.clear()
	check(not _storages.has(PILE), "the pile is gone")
	check_eq(_storages.capacity_total(WOOD), 0)
	check_eq(_storages.stored_total(WOOD), 0)
	check_eq(_storages.free_total(WOOD), 0)
	check_eq(_storages.ids().size(), 0)


## The pile holds 1 unit, unclaimed, and nothing is coming.
func _check_the_pile_is_as_it_was() -> void:
	check_eq(_storages.stored_in(PILE), 1)
	check_eq(_storages.free_in(PILE), 1)
	check_eq(_storages.room_in(PILE), 2)
	check_eq(_storages.stored_total(WOOD), 1)
	check_eq(_storages.free_total(WOOD), 1)
