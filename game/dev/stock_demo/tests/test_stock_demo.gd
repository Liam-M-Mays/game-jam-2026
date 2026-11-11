extends GameTest
## Checks the stock demo: its commands do what its keys say, and its
## stand-in for nature and haulers plays the same film for the same seed.

const StockDemo := preload("res://game/dev/stock_demo/stock_demo.gd")
const DemoWork := preload("res://game/dev/stock_demo/demo_work.gd")

const TICKS_PER_SECOND := 20
const SPOT := Vector2(8.0, 6.0)

var _village: Village
var _stock: VillageStock
var _work: DemoWork
var _wood: int
var _stone: int
var _food: int


## The village of the demo, with no window.
func before_each() -> void:
	_village = _new_village(StockDemo.VILLAGE_SEED)
	_stock = _village.part(Village.STOCK)
	_work = _village.part(&"demo_work")
	_wood = _stock.number_of(&"wood")
	_stone = _stock.number_of(&"stone")
	_food = _stock.number_of(&"food")


func test_a_click_lays_one_drop_on_the_spot_under_the_mouse() -> void:
	check(_village.send(StockDemo.LayDrop.new(&"wood", SPOT)), "wood on the map")
	check(_village.send(StockDemo.LayDrop.new(&"stone", SPOT + Vector2(2.0, 0.0))), "stone too")
	check(not _village.send(StockDemo.LayDrop.new(&"wood", Vector2(9000.0, 0.0))), "off the map")
	check_eq(_stock.count(_wood), 1)
	check_eq(_stock.count(_stone), 1)
	check_eq(_village.grid.drops.spot_of(0), SPOT, "it lies on the spot of the click")


func test_the_food_keys_add_and_spend_and_a_silo_raises_the_cap() -> void:
	check(_village.send(StockDemo.ChangeFood.new(2)), "pick a bush")
	check_eq(_stock.count(_food), 12)
	check(_village.send(StockDemo.ChangeFood.new(-5)), "eat 5")
	check_eq(_stock.count(_food), 7)
	check(_village.send(StockDemo.ChangeFood.new(99)), "fill up")
	check_eq(_stock.count(_food), 20)
	check(not _village.send(StockDemo.ChangeFood.new(2)), "full: the bush is refused")
	# The Q key puts each new silo one step further along the top of the map.
	for index in 5:
		var cell := StockDemo.FIRST_SILO_CELL + StockDemo.SILO_STEP * index
		check(_village.send(StockDemo.AddSilo.new(GridLayout.position_of(cell))), "silo %d" % index)
	check_eq(_stock.cap(_food), 120)
	check(not _village.send(StockDemo.AddSilo.new(Vector2(9000.0, 0.0))), "no silo off the map")


func test_a_burst_lays_1000_drops_and_hauling_can_be_turned_off() -> void:
	_village.send(StockDemo.TellWork.new(StockDemo.BURST, false))
	check_eq(_stock.count(_wood), 500)
	check_eq(_stock.count(_stone), 500)
	check(_work.hauling, "hauling starts on")
	_village.send(StockDemo.TellWork.new(0, true))
	check(not _work.hauling, "H turns it off")
	for tick in 600:
		_village.tick()
	check_eq(_work.trips.size(), 0, "nothing is hauled while it is off")
	check_eq(_stock.claims.carried(_wood) + _stock.claims.carried(_stone), 0)
	check(_stock.count(_wood) > 500, "but things still break and leave drops")
	check_eq(_village.grid.drops.loose(_wood), _stock.count(_wood), "and every one stays loose")


func test_the_demo_plays_the_same_film_for_the_same_seed() -> void:
	var first := _run(_new_village(63))
	var second := _run(_new_village(63))
	var other := _run(_new_village(64))
	check_eq(first.snapshot(), second.snapshot())
	check_eq(first.state_hash(), second.state_hash())
	check(first.snapshot() != other.snapshot(), "another seed plays another film")


func test_the_demo_hauls_and_stores_and_its_numbers_stay_right() -> void:
	_run(_village)
	var piled := _stock.storages.stored_total(_wood) + _stock.storages.stored_total(_stone)
	check(piled > 0, "the piles got something: %d" % piled)
	check(_stock.count(_wood) > 20, "wood was made: %d" % _stock.count(_wood))
	check(_village.grid.drops.looked_at > 0, "a lookup ran")
	for kind: int in [_wood, _stone]:
		check(_stock.claims.available(kind) >= 0, "nothing is promised twice")
		var parts := _village.grid.drops.total(kind) + _stock.storages.stored_total(kind)
		check_eq(_stock.count(kind), parts + _stock.claims.carried(kind))
	check(_stock.count(_food) <= _stock.cap(_food), "food stays under its cap")
	check(_stock.count(_food) >= 0, "and never goes below zero")


func _new_village(village_seed: int) -> Village:
	var village := Village.new(village_seed, TICKS_PER_SECOND)
	var cells := GridLayout.offsets_within(StockDemo.MAP_STEPS)
	for cell in cells:
		village.grid.add_cell(cell)
	village.add_part(Village.STOCK, VillageStock.new(ResourceKind.load_all()))
	village.add_part(&"demo_work", DemoWork.new(cells.duplicate()))
	return village


## One minute of the demo.
func _run(village: Village) -> Village:
	for tick in 1200:
		village.tick()
	return village
