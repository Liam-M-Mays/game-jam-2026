extends GameTest
## The random test of issue #63: 10,000 random steps on one stock. No number
## may go below zero, and no unit may be handed out twice.
##
## The test keeps its own book beside the stock: who holds which drop, and
## how many units there should be. After every step it compares the two.

const TICKS_PER_SECOND := 20
const STEPS := 10000
const SITES: Array[int] = [601, 602, 603]
const HAULS := 16
const FIRST_HAUL := 701
const FIRST_STORAGE := 501
const MOST_STORAGES := 9
const MAP := Vector2i(30, 30)

var _village: Village
var _stock: VillageStock
var _claims: StockClaims
var _drops: GridDrops
var _rng := RandomNumberGenerator.new()
var _items: Array[int] = []
var _food: int

# The book of the test.
var _expected: Dictionary[int, int] = {}
var _holder_of_drop: Dictionary[int, int] = {}
var _claims_on_pile: Dictionary[int, int] = {}
var _held: Dictionary[int, Dictionary] = {}
var _piles: Array[int] = []
var _silos := 0

# What went wrong, and what was done.
var _below_zero := 0
var _handed_out_twice := 0
var _wrong_count := 0
var _done: Dictionary[String, int] = {}


## A village with a block of cells and a stock from the data files.
func before_each() -> void:
	_rng.seed = 6300
	_village = Village.new(63, TICKS_PER_SECOND)
	for cell in GridLayout.block(Vector2i(0, 0), MAP):
		_village.grid.add_cell(cell)
	_stock = VillageStock.new(ResourceKind.load_all())
	_village.add_part(Village.STOCK, _stock)
	_claims = _stock.claims
	_drops = _village.grid.drops
	_items = [_stock.number_of(&"wood"), _stock.number_of(&"stone")]
	_food = _stock.number_of(&"food")
	_expected = {_items[0]: 0, _items[1]: 0, _food: 10}


func test_10000_random_steps_never_go_below_zero_or_hand_a_unit_out_twice() -> void:
	for step in STEPS:
		_one_step()
		_village.tick()
		_compare_with_the_book()
	check_eq(_below_zero, 0, "numbers that went below zero")
	check_eq(_handed_out_twice, 0, "units that were handed out twice")
	check_eq(_wrong_count, 0, "steps after which the stock and the book disagreed")
	# The run has to have done real work of every kind.
	for what: String in ["drop", "reserve", "claim", "trip", "pick_up", "deliver", "store"]:
		check(_done.get(what, 0) >= 100, "%s happened %d times" % [what, _done.get(what, 0)])
	check(_done.get("release", 0) >= 100, "release happened %d times" % _done.get("release", 0))
	check(_done.get("from_pile", 0) >= 20, "claims on a pile: %d" % _done.get("from_pile", 0))
	check_eq(_village.now, STEPS)
	print("STOCK_RANDOM %s" % [_done])


func _one_step() -> void:
	var roll := _rng.randi_range(0, 99)
	var kind := _items[_rng.randi_range(0, 1)]
	var haul := FIRST_HAUL + _rng.randi_range(0, HAULS - 1)
	var site := SITES[_rng.randi_range(0, SITES.size() - 1)]
	if roll < 18:
		_drop(kind)
	elif roll < 23:
		_expected[_food] += _stock.add(_food, _rng.randi_range(1, 5))
	elif roll < 28:
		_expected[_food] -= _stock.spend(_food, _rng.randi_range(1, 6))
	elif roll < 31:
		_add_storage()
	elif roll < 40:
		if _claims.reserve(site, kind, _rng.randi_range(1, 3)):
			_count("reserve")
	elif roll < 44:
		_claims.unreserve(site, kind, _rng.randi_range(1, 2))
	elif roll < 58:
		_claim(haul, site, kind)
	elif roll < 70:
		_start_trip(haul)
	elif roll < 84:
		_pick_up(haul)
	elif roll < 95:
		_hand_over(haul)
	else:
		_release(haul)


func _drop(kind: int) -> void:
	if _stock.drop(kind, _random_spot()) != GridDrops.NO_DROP:
		_expected[kind] += 1
		_count("drop")


func _add_storage() -> void:
	var id := FIRST_STORAGE + _piles.size() + _silos
	if _piles.size() + _silos >= MOST_STORAGES:
		return
	if _rng.randf() < 0.3:
		if _stock.add_storage(id, _food, 20, _random_spot()):
			_silos += 1
		return
	var kind := _items[_rng.randi_range(0, 1)]
	if _stock.add_storage(id, kind, _rng.randi_range(10, 40), _random_spot()):
		_piles.append(id)
		_claims_on_pile[id] = 0


func _claim(haul: int, site: int, kind: int) -> void:
	# Every third hauler stands at a pile, so that units in piles get claimed too.
	var from := _random_spot()
	if not _piles.is_empty() and _rng.randi_range(0, 2) == 0:
		from = _stock.storages.spot_of(_piles[_rng.randi_range(0, _piles.size() - 1)])
	if not _claims.claim_closest(haul, site, kind, from):
		return
	_count("claim")
	var drop := _claims.drop_of(haul)
	var pile := _claims.storage_of(haul)
	if drop != GridDrops.NO_DROP:
		_note_drop(drop, haul)
	else:
		_count("from_pile")
		_claims_on_pile[pile] += 1
		if _claims_on_pile[pile] > _stock.storages.stored_in(pile):
			_handed_out_twice += 1
	_held[haul] = {"kind": kind, "drop": drop, "pile": pile, "to_pile": false}


func _start_trip(haul: int) -> void:
	if _piles.is_empty():
		return
	var pile := _piles[_rng.randi_range(0, _piles.size() - 1)]
	var kind := _stock.storages.kind_of(pile)
	var drop := _drops.closest(kind, _random_spot())
	if not _claims.claim_for_storage(haul, pile, drop):
		return
	_count("trip")
	_note_drop(drop, haul)
	_held[haul] = {"kind": kind, "drop": drop, "pile": 0, "to_pile": true}


func _pick_up(haul: int) -> void:
	if not _claims.pick_up(haul):
		return
	_count("pick_up")
	_let_go_of_the_source(haul)


func _hand_over(haul: int) -> void:
	if not _claims.hand_over(haul):
		return
	if _held[haul]["to_pile"]:
		_count("store")
	else:
		_count("deliver")
		_expected[_held[haul]["kind"]] -= 1
	_held.erase(haul)


func _release(haul: int) -> void:
	var spot := _random_spot() if _rng.randf() < 0.8 else Vector2(-900.0, -900.0)
	if not _claims.release(haul, spot):
		return
	_count("release")
	_let_go_of_the_source(haul)
	_held.erase(haul)


## Writes into the book that [param haul] holds [param drop]. A drop that is
## in the book already was handed out twice.
func _note_drop(drop: int, haul: int) -> void:
	if _holder_of_drop.has(drop) or _drops.claimer_of(drop) != haul:
		_handed_out_twice += 1
	_holder_of_drop[drop] = haul


func _let_go_of_the_source(haul: int) -> void:
	var held: Dictionary = _held[haul]
	if held["drop"] != GridDrops.NO_DROP:
		_holder_of_drop.erase(held["drop"])
		held["drop"] = GridDrops.NO_DROP
	elif held["pile"] != StockStorages.NO_STORAGE:
		_claims_on_pile[held["pile"]] -= 1
		held["pile"] = StockStorages.NO_STORAGE


func _compare_with_the_book() -> void:
	for kind: int in _expected:
		var numbers: Array[int] = [
			_stock.count(kind),
			_claims.available(kind),
			_claims.carried(kind),
			_drops.total(kind),
			_drops.loose(kind),
			_drops.total(kind) - _drops.loose(kind),
		]
		if numbers.min() < 0:
			_below_zero += 1
		if _stock.count(kind) != _expected[kind]:
			_wrong_count += 1
	if _stock.count(_food) > _stock.cap(_food):
		_wrong_count += 1
	for pile in _stock.storages.ids():
		var storages := _stock.storages
		if mini(storages.stored_in(pile), mini(storages.free_in(pile), storages.room_in(pile))) < 0:
			_below_zero += 1
	for site in SITES:
		for kind in _items:
			if _claims.reserved_by(site, kind) < 0:
				_below_zero += 1


func _random_spot() -> Vector2:
	var cell := Vector2i(_rng.randi_range(0, MAP.x - 1), _rng.randi_range(0, MAP.y - 1))
	var middle := GridLayout.position_of(cell) + GridLayout.CELL_MIDDLE
	return middle + Vector2(_rng.randf_range(-3.4, 3.4), _rng.randf_range(-2.4, 2.4))


func _count(what: String) -> void:
	_done[what] = _done.get(what, 0) + 1
