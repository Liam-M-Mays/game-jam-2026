extends GameTest
## The random test of issue #63: 10,000 random steps on one stock. No number
## may go below zero, and no unit may be handed out twice.
##
## The test keeps its own book beside the stock: who holds which drop, how
## many units there should be, how many lie loose, how many sit free in the
## piles, and what each site has reserved. After every step it compares the
## two. Every few hundred steps it also counts the rows of each cell.
##
## Two kinds of step take a drop off the ground without the stock: a loose
## one, and one a hauler has claimed, taken with the id of that hauler.

const TICKS_PER_SECOND := 20
const STEPS := 10000
const SITES: Array[int] = [601, 602, 603]
const HAULS := 16
const FIRST_HAUL := 701
const FIRST_STORAGE := 501
const MOST_STORAGES := 9
const MAP := Vector2i(30, 30)
const COUNT_THE_CELLS_EVERY := 250

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
var _loose: Dictionary[int, int] = {}
var _free_in_piles: Dictionary[int, int] = {}
var _reserved: Dictionary[int, Dictionary] = {}
var _piles: Array[int] = []
var _silos := 0

# What went wrong, and what was done.
var _below_zero := 0
var _handed_out_twice := 0
var _wrong_count := 0
var _wrong_promise := 0
var _wrong_cells := 0
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
	_loose = {_items[0]: 0, _items[1]: 0}
	_free_in_piles = {_items[0]: 0, _items[1]: 0}
	for site in SITES:
		_reserved[site] = {_items[0]: 0, _items[1]: 0}


func test_10000_random_steps_never_go_below_zero_or_hand_a_unit_out_twice() -> void:
	for step in STEPS:
		_one_step()
		_village.tick()
		_compare_with_the_book()
		if step % COUNT_THE_CELLS_EVERY == 0:
			_count_the_cells()
	check_eq(_below_zero, 0, "numbers that went below zero")
	check_eq(_handed_out_twice, 0, "units that were handed out twice")
	check_eq(_wrong_count, 0, "steps after which the stock and the book disagreed")
	check_eq(_wrong_promise, 0, "steps after which a promise and the book disagreed")
	check_eq(_wrong_cells, 0, "cells whose count and rows disagreed")
	# The run has to have done real work of every kind.
	for what: String in ["drop", "reserve", "claim", "trip", "pick_up", "deliver", "store"]:
		check(_done.get(what, 0) >= 100, "%s happened %d times" % [what, _done.get(what, 0)])
	for what: String in ["release", "taken_off_the_ground"]:
		check(_done.get(what, 0) >= 100, "%s happened %d times" % [what, _done.get(what, 0)])
	check(_done.get("from_pile", 0) >= 20, "claims on a pile: %d" % _done.get("from_pile", 0))
	var lost: int = _done.get("reservation_lost", 0)
	check(lost >= 20, "reservations that went with a taken drop: %d" % lost)
	var taken: int = _done.get("claimed_drop_taken", 0)
	check(taken >= 20, "claimed drops taken off the ground: %d" % taken)
	var ended: int = _done.get("lost_claim_ended", 0)
	check(ended >= 20, "hauls that found their drop gone: %d" % ended)
	check_eq(_village.now, STEPS)
	print("STOCK_RANDOM %s" % [_done])


func _one_step() -> void:
	var roll := _rng.randi_range(0, 99)
	var kind := _items[_rng.randi_range(0, 1)]
	var haul := FIRST_HAUL + _rng.randi_range(0, HAULS - 1)
	var site := SITES[_rng.randi_range(0, SITES.size() - 1)]
	if roll < 16:
		_drop(kind)
	elif roll < 20:
		_expected[_food] += _stock.add(_food, _rng.randi_range(1, 5))
	elif roll < 24:
		_expected[_food] -= _stock.spend(_food, _rng.randi_range(1, 6))
	elif roll < 27:
		_add_storage()
	elif roll < 36:
		_reserve(site, kind)
	elif roll < 40:
		_unreserve(site, kind)
	elif roll < 54:
		_claim(haul, site, kind)
	elif roll < 66:
		_start_trip(haul)
	elif roll < 80:
		_pick_up(haul)
	elif roll < 91:
		_hand_over(haul)
	elif roll < 95:
		_release(haul)
	elif roll < 98:
		_take_off_the_ground(kind)
	else:
		_take_a_claimed_drop(haul)


func _drop(kind: int) -> void:
	if _stock.drop(kind, _random_spot()) != GridDrops.NO_DROP:
		_expected[kind] += 1
		_loose[kind] += 1
		_count("drop")


## A site reserves 1 to 3 units. Every fourth time it asks for everything
## that is left, so that the stock is often fully promised.
func _reserve(site: int, kind: int) -> void:
	var amount := _rng.randi_range(1, 3)
	if _rng.randi_range(0, 3) == 0:
		amount = maxi(_free_to_promise(kind), 1)
	var should_work := amount <= _free_to_promise(kind)
	if _claims.reserve(site, kind, amount) != should_work:
		_wrong_promise += 1
	if should_work:
		_reserved[site][kind] += amount
		_count("reserve")


func _unreserve(site: int, kind: int) -> void:
	var amount := _rng.randi_range(1, 2)
	var should_give: int = mini(amount, _reserved[site][kind])
	if _claims.unreserve(site, kind, amount) != should_give:
		_wrong_promise += 1
	_reserved[site][kind] -= should_give


## A loose drop is taken off the ground without the stock being asked, with
## one of the two plain calls of the ground. When every unit was reserved, the
## newest site loses a reservation.
func _take_off_the_ground(kind: int) -> void:
	var drop := _drops.closest(kind, _random_spot())
	if drop == GridDrops.NO_DROP:
		return
	if _rng.randi_range(0, 1) == 0:
		if not _drops.remove(drop):
			_wrong_count += 1
	elif _drops.take(_drops.cell_of(drop), kind, 1) != 1:
		_wrong_count += 1
	_count("taken_off_the_ground")
	_expected[kind] -= 1
	_loose[kind] -= 1
	for at in range(SITES.size() - 1, -1, -1):
		while _free_to_promise(kind) < 0 and _reserved[SITES[at]][kind] > 0:
			_reserved[SITES[at]][kind] -= 1
			_count("reservation_lost")


## A drop that a hauler has claimed is taken off the ground with the id of
## that hauler, without the stock being asked. It is the drop of
## [param first], or of the next hauler that has one on the ground. The claim
## stays until that hauler tries to pick up or to release.
func _take_a_claimed_drop(first: int) -> void:
	for offset in HAULS:
		var haul := FIRST_HAUL + (first - FIRST_HAUL + offset) % HAULS
		var held: Dictionary = _held.get(haul, {})
		if held.get("drop", GridDrops.NO_DROP) == GridDrops.NO_DROP:
			continue
		if not _drops.remove(held["drop"], haul):
			_wrong_count += 1
		_count("claimed_drop_taken")
		_expected[held["kind"]] -= 1
		_holder_of_drop.erase(held["drop"])
		held["drop"] = GridDrops.NO_DROP
		held["lost"] = true
		return


## A haul whose drop was taken finds that out when a pick up or a release is
## refused: its claim has ended, and no unit and no reservation came back.
func _end_when_lost(haul: int) -> void:
	if not _held.has(haul) or not _held[haul].get("lost", false):
		return
	if _claims.has(haul):
		_wrong_promise += 1
	_count("lost_claim_ended")
	_held.erase(haul)


## True when a step worked for [param haul] that the book says holds
## nothing, or whose drop is gone. Then it worked on the unit of somebody
## else. The book lets go of the haul, so the run goes on to its end.
func _took_what_is_not_its_own(haul: int) -> bool:
	if _held.has(haul) and not _held[haul].get("lost", false):
		return false
	_handed_out_twice += 1
	_held.erase(haul)
	return true


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
	var should_work: bool = not _held.has(haul) and _reserved[site][kind] > 0
	if _claims.claim_closest(haul, site, kind, from) != should_work:
		_wrong_promise += 1
	if not _claims.has(haul) or not should_work:
		return
	_count("claim")
	_reserved[site][kind] -= 1
	var drop := _claims.drop_of(haul)
	var pile := _claims.storage_of(haul)
	if drop != GridDrops.NO_DROP:
		_note_drop(drop, haul)
		_loose[kind] -= 1
	else:
		_count("from_pile")
		_free_in_piles[kind] -= 1
		_claims_on_pile[pile] += 1
		if _claims_on_pile[pile] > _stock.storages.stored_in(pile):
			_handed_out_twice += 1
	_held[haul] = {
		"kind": kind, "site": site, "drop": drop, "pile": pile, "to_pile": false, "carried": false
	}


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
	_loose[kind] -= 1
	_held[haul] = {
		"kind": kind, "site": 0, "drop": drop, "pile": 0, "to_pile": true, "carried": false
	}


func _pick_up(haul: int) -> void:
	if not _claims.pick_up(haul):
		_end_when_lost(haul)
		return
	if _took_what_is_not_its_own(haul):
		return
	_count("pick_up")
	_let_go_of_the_source(haul)
	_held[haul]["carried"] = true


func _hand_over(haul: int) -> void:
	if not _claims.hand_over(haul) or _took_what_is_not_its_own(haul):
		return
	if _held[haul]["to_pile"]:
		_count("store")
		_free_in_piles[_held[haul]["kind"]] += 1
	else:
		_count("deliver")
		_expected[_held[haul]["kind"]] -= 1
	_held.erase(haul)


func _release(haul: int) -> void:
	var spot := _random_spot() if _rng.randf() < 0.8 else Vector2(-900.0, -900.0)
	if not _claims.release(haul, spot):
		_end_when_lost(haul)
		return
	if _took_what_is_not_its_own(haul):
		return
	_count("release")
	# The unit is free again: put down or unclaimed on the ground, or still in
	# its pile. A haul for a site gives the site its reservation back.
	var held: Dictionary = _held[haul]
	if held["carried"] or held["drop"] != GridDrops.NO_DROP:
		_loose[held["kind"]] += 1
	else:
		_free_in_piles[held["kind"]] += 1
	if not held["to_pile"]:
		_reserved[held["site"]][held["kind"]] += 1
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
	for kind in _items:
		var right := (
			_drops.loose(kind) == _loose[kind]
			and _stock.storages.free_total(kind) == _free_in_piles[kind]
			and _claims.available(kind) == _free_to_promise(kind)
		)
		for site in SITES:
			right = right and _claims.reserved_by(site, kind) == _reserved[site][kind]
		if not right:
			_wrong_promise += 1


## What the book says can still be promised of [param kind].
func _free_to_promise(kind: int) -> int:
	var reserved := 0
	for site in SITES:
		reserved += _reserved[site][kind]
	return _loose[kind] + _free_in_piles[kind] - reserved


## Counts the rows of every cell and compares with the count the cell keeps.
func _count_the_cells() -> void:
	var from_rows: Dictionary[Vector3i, int] = {}
	for drop in _drops.size():
		if _drops.has(drop):
			var cell := _drops.cell_of(drop)
			var key := Vector3i(cell.x, cell.y, _drops.kind_of(drop))
			from_rows[key] = from_rows.get(key, 0) + 1
	for cell in GridLayout.block(Vector2i(0, 0), MAP):
		for kind in _items:
			if _drops.count_at(cell, kind) != from_rows.get(Vector3i(cell.x, cell.y, kind), 0):
				_wrong_cells += 1


func _random_spot() -> Vector2:
	var cell := Vector2i(_rng.randi_range(0, MAP.x - 1), _rng.randi_range(0, MAP.y - 1))
	var middle := GridLayout.position_of(cell) + GridLayout.CELL_MIDDLE
	return middle + Vector2(_rng.randf_range(-3.4, 3.4), _rng.randf_range(-2.4, 2.4))


func _count(what: String) -> void:
	_done[what] = _done.get(what, 0) + 1
