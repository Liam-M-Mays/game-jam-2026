extends GameTest
## Checks the stock of a village: the numbers, the food cap, what counts,
## and that every change is told.

const TICKS_PER_SECOND := 20
const SILO := 501
const OTHER_SILO := 502
const WOOD_PILE := 503
const SITE := 601
const HAUL := 701
## What one silo adds to the food cap in the jam game.
const SILO_FOOD := 20
const SPOT := Vector2(31.0, 10.0)

var _village: Village
var _stock: VillageStock
var _wood: int
var _stone: int
var _food: int
var _heard: Array[int] = []


## A village with a block of cells and a stock from the data files.
func before_each() -> void:
	_village = _new_village(63)
	_stock = _village.part(Village.STOCK)
	_wood = _stock.number_of(&"wood")
	_stone = _stock.number_of(&"stone")
	_food = _stock.number_of(&"food")


func test_a_new_village_starts_with_10_food_and_no_wood_or_stone() -> void:
	check_eq(_stock.count(_food), 10)
	check_eq(_stock.count(_wood), 0)
	check_eq(_stock.count(_stone), 0)
	check_eq(_stock.claims.available(_wood), 0)


func test_each_village_has_its_own_stock_and_a_new_one_starts_fresh() -> void:
	_stock.spend(_food, 7)
	_stock.drop(_wood, SPOT)
	_stock.add_storage(SILO, _food, SILO_FOOD, SPOT)
	_stock.claims.reserve(SITE, _wood)
	var next := _new_village(64)
	var fresh: VillageStock = next.part(Village.STOCK)
	check_eq(_stock.count(_food), 3)
	check_eq(fresh.count(_food), 10, "the next village has the starting food")
	check_eq(fresh.count(_wood), 0)
	check_eq(fresh.cap(_food), 20)
	check_eq(fresh.claims.reserved_by(SITE, _wood), 0, "and nothing is reserved")
	fresh.add(_food, 5)
	check_eq(_stock.count(_food), 3, "a change in one village does not reach the other")


func test_adding_and_spending_food_changes_the_number() -> void:
	check_eq(_stock.add(_food, 4), 4)
	check_eq(_stock.count(_food), 14)
	check_eq(_stock.spend(_food, 9), 9)
	check_eq(_stock.count(_food), 5)
	check_eq(_stock.add(_food, 0), 0)
	check_eq(_stock.add(_food, -3), 0)
	check_eq(_stock.spend(_food, -3), 0)
	check_eq(_stock.count(_food), 5)


func test_the_food_cap_is_20_plus_the_capacity_of_every_silo() -> void:
	check_eq(_stock.cap(_food), 20)
	check(_stock.add_storage(SILO, _food, SILO_FOOD, SPOT), "a silo can be added")
	check_eq(_stock.cap(_food), 40)
	_stock.add_storage(OTHER_SILO, _food, SILO_FOOD, SPOT)
	check_eq(_stock.cap(_food), 60)
	check_eq(_stock.add(_food, 100), 50, "food fills up to the new cap")
	check_eq(_stock.count(_food), 60)


func test_food_added_above_the_cap_is_lost() -> void:
	_stock.add(_food, 9)
	check_eq(_stock.count(_food), 19)
	check_eq(_stock.add(_food, 2), 1, "19 of 20 plus a pick of 2 gives 20")
	check_eq(_stock.count(_food), 20)
	check_eq(_stock.add(_food, 2), 0)
	check_eq(_stock.count(_food), 20)


func test_food_is_full_at_or_above_the_cap() -> void:
	check(not _stock.is_full(_food), "10 of 20 is not full")
	_stock.add(_food, 9)
	check(not _stock.is_full(_food), "19 of 20 is not full")
	_stock.add(_food, 1)
	check(_stock.is_full(_food), "20 of 20 is full")
	_stock.spend(_food, 1)
	check(not _stock.is_full(_food), "19 of 20 is not full again")


func test_spending_more_than_there_is_empties_the_stock_to_zero() -> void:
	check_eq(_stock.spend(_food, 25), 10)
	check_eq(_stock.count(_food), 0)
	check_eq(_stock.spend(_food, 1), 0)
	check_eq(_stock.count(_food), 0)


func test_a_drop_counts_the_moment_it_appears_and_stops_when_it_is_taken() -> void:
	var drop := _stock.drop(_wood, SPOT)
	check_eq(_stock.count(_wood), 1, "it counts before anybody picks it up")
	check_eq(_stock.claims.available(_wood), 1)
	_stock.drop(_wood, SPOT + Vector2(20.0, 5.0))
	_stock.drop(_stone, SPOT)
	check_eq(_stock.count(_wood), 2)
	check_eq(_stock.count(_stone), 1)
	_village.grid.drops.remove(drop)
	check_eq(_stock.count(_wood), 1, "a drop that left the world no longer counts")


func test_the_number_counts_the_ground_the_piles_and_what_is_carried() -> void:
	_stock.add_storage(WOOD_PILE, _wood, 4, SPOT)
	for i in 3:
		_stock.drop(_wood, SPOT + Vector2(14.0 * i, 0.0))
	# One unit goes into the pile, one is carried to a site, one stays on the ground.
	_stock.claims.claim_for_storage(HAUL, WOOD_PILE, 0)
	_stock.claims.pick_up(HAUL)
	check_eq(_stock.count(_wood), 3, "ground 2, carried 1")
	_stock.claims.hand_over(HAUL)
	check_eq(_stock.count(_wood), 3, "ground 2, pile 1")
	_stock.claims.reserve(SITE, _wood)
	_stock.claims.claim_closest(HAUL, SITE, _wood, Vector2(200.0, 0.0))
	_stock.claims.pick_up(HAUL)
	check_eq(_village.grid.drops.total(_wood), 1)
	check_eq(_stock.storages.stored_in(WOOD_PILE), 1)
	check_eq(_stock.claims.carried(_wood), 1)
	check_eq(_stock.count(_wood), 3, "ground 1, pile 1, carried 1")
	_stock.claims.hand_over(HAUL)
	check_eq(_stock.count(_wood), 2, "the delivered unit left the stock")


func test_wood_and_stone_are_never_banked_as_a_number() -> void:
	check_eq(_stock.add(_wood, 5), 0)
	check_eq(_stock.add(_stone, 5), 0)
	check_eq(_stock.count(_wood), 0)
	check_eq(_stock.count(_stone), 0)
	_stock.drop(_wood, SPOT)
	check_eq(_stock.spend(_wood, 1), 0, "a drop cannot be spent like a number")
	check_eq(_stock.count(_wood), 1)
	check_eq(_stock.snapshot()["banked"], {_food: 10}, "only food is in the bank")


func test_food_is_never_an_item() -> void:
	check_eq(_stock.drop(_food, SPOT), GridDrops.NO_DROP)
	check_eq(_village.grid.drops.total(_food), 0)
	check_eq(_stock.count(_food), 10)


func test_the_cap_of_wood_is_the_room_in_its_piles_and_the_ground_has_no_cap() -> void:
	check_eq(_stock.cap(_wood), 0)
	_stock.add_storage(WOOD_PILE, _wood, 4, SPOT)
	check_eq(_stock.cap(_wood), 4)
	for i in 9:
		check(_stock.drop(_wood, SPOT) != GridDrops.NO_DROP, "wood can always be dropped")
	check_eq(_stock.count(_wood), 9, "have can be higher than room")
	check(not _stock.is_full(_wood), "an item kind is never full")


func test_a_storage_needs_a_free_id_a_known_kind_and_a_cell() -> void:
	check(_stock.add_storage(WOOD_PILE, _wood, 4, SPOT), "a pile on a cell")
	check(not _stock.add_storage(WOOD_PILE, _wood, 4, SPOT), "the id is taken")
	check(not _stock.add_storage(SILO, 99, 4, SPOT), "kind 99 is not known")
	check(not _stock.add_storage(SILO, _food, 4, Vector2(-900.0, -900.0)), "no cell there")
	check(not _stock.add_storage(0, _food, 4, SPOT), "id 0 means no storage")
	check(not _stock.add_storage(SILO, _food, -1, SPOT), "a capacity below zero")
	check_eq(_stock.cap(_wood), 4)
	check_eq(_stock.cap(_food), 20)
	check_eq(_stock.storages.ids(), PackedInt32Array([WOOD_PILE]))


func test_every_change_is_told_once_with_its_kind() -> void:
	_stock.changed.connect(_hear)
	_stock.add(_food, 2)
	_stock.spend(_food, 1)
	_stock.add_storage(SILO, _food, SILO_FOOD, SPOT)
	var drop := _stock.drop(_stone, SPOT)
	_village.grid.drops.add(Vector2i(2, 2), _wood)
	_village.grid.drops.remove(drop)
	check_eq(_heard, [_food, _food, _food, _stone, _wood, _stone] as Array[int])


func test_a_call_that_changes_nothing_is_not_told() -> void:
	_stock.changed.connect(_hear)
	_stock.spend(_food, 0)
	_stock.add(_food, 0)
	_stock.add(_wood, 3)
	_stock.drop(_food, SPOT)
	_stock.drop(_wood, Vector2(-900.0, -900.0))
	_stock.add_storage(SILO, 99, 4, SPOT)
	_stock.spend(_food, 99)
	_stock.spend(_food, 5)
	_stock.add(_food, 99)
	_stock.add(_food, 1)
	check_eq(_heard, [_food, _food] as Array[int], "only the spend to zero and the fill to the cap")


func test_a_kind_is_found_by_its_name_and_by_its_number() -> void:
	check_eq(_wood, 1)
	check_eq(_stone, 2)
	check_eq(_food, 3)
	check_eq(_stock.number_of(&"gold"), VillageStock.NO_KIND)
	check_eq(_stock.data_of(_stone).id, &"stone")
	check_eq(_stock.data_of(99), null)
	check_eq(_stock.kind_numbers(), PackedInt32Array([1, 2, 3]))


func test_the_numbers_come_from_the_data_and_can_be_changed_there() -> void:
	var grain := ResourceKind.new()
	grain.id = &"grain"
	grain.number = 7
	grain.start_amount = 3
	grain.base_cap = 5
	var village := Village.new(1, TICKS_PER_SECOND)
	var stock := VillageStock.new([grain] as Array[ResourceKind])
	village.add_part(Village.STOCK, stock)
	check_eq(stock.count(7), 3)
	check_eq(stock.cap(7), 5)
	check_eq(stock.add(7, 10), 2)
	check(stock.is_full(7), "full at its own cap")
	check_eq(stock.number_of(&"food"), VillageStock.NO_KIND)


func test_two_kinds_cannot_share_a_number_or_a_name() -> void:
	var first := ResourceKind.new()
	first.id = &"first"
	first.number = 4
	var same_number := ResourceKind.new()
	same_number.id = &"second"
	same_number.number = 4
	var same_name := ResourceKind.new()
	same_name.id = &"first"
	same_name.number = 5
	# The two refusals log an error each. That is on purpose.
	var stock := VillageStock.new([first, same_number, same_name] as Array[ResourceKind])
	check_eq(stock.kind_numbers(), PackedInt32Array([4]))
	check_eq(stock.number_of(&"first"), 4)
	check_eq(stock.number_of(&"second"), VillageStock.NO_KIND)


func _new_village(village_seed: int) -> Village:
	var village := Village.new(village_seed, TICKS_PER_SECOND)
	for cell in GridLayout.block(Vector2i(0, 0), Vector2i(40, 20)):
		village.grid.add_cell(cell)
	village.add_part(Village.STOCK, VillageStock.new(ResourceKind.load_all()))
	return village


func _hear(kind: int) -> void:
	_heard.append(kind)
