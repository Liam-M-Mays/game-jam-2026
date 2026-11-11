class_name StockStorages
extends RefCounted
## The storage buildings of a village, as counts.
##
## A storage holds a count of one resource kind, up to its capacity. It is
## named by the id of its building. The building itself comes with #67: this
## is only the stock side of it.
## - A storage of an item kind, such as a wood pile, holds units.
## - A storage of a banked kind, such as a silo, holds nothing itself. Its
##   capacity raises the cap of the kind.
##
## Reach it as [member VillageStock.storages]. Everyone may read the numbers.
## Game code adds a storage with [method VillageStock.add_storage] and moves
## units through [StockClaims]. [method add] and [method change] are the plain
## steps those two are built from.

## The answer when there is no storage.
const NO_STORAGE := 0

var _kinds: Dictionary[int, int] = {}
var _spots: Dictionary[int, Vector2] = {}
var _capacities: Dictionary[int, int] = {}
var _stored: Dictionary[int, int] = {}
var _claimed: Dictionary[int, int] = {}
var _coming: Dictionary[int, int] = {}
var _capacity_totals: Dictionary[int, int] = {}
var _stored_totals: Dictionary[int, int] = {}
var _claimed_totals: Dictionary[int, int] = {}


## Adds the storage [param storage], an id above zero, for [param kind]. It
## holds up to [param capacity] units and stands at [param spot], in art
## pixels. Returns false when the id is taken or a number is not valid.
func add(storage: int, kind: int, capacity: int, spot: Vector2) -> bool:
	if storage <= NO_STORAGE or _kinds.has(storage) or kind <= 0 or capacity < 0:
		return false
	_kinds[storage] = kind
	_spots[storage] = spot
	_capacities[storage] = capacity
	_stored[storage] = 0
	_claimed[storage] = 0
	_coming[storage] = 0
	_capacity_totals[kind] = _capacity_totals.get(kind, 0) + capacity
	return true


## True when [param storage] was added.
func has(storage: int) -> bool:
	return _kinds.has(storage)


## The kind [param storage] holds. 0 when there is no such storage.
func kind_of(storage: int) -> int:
	return _kinds.get(storage, 0)


## Where [param storage] stands, in art pixels.
func spot_of(storage: int) -> Vector2:
	return _spots.get(storage, Vector2.ZERO)


## How many units [param storage] can hold.
func capacity_of(storage: int) -> int:
	return _capacities.get(storage, 0)


## How many units are in [param storage] now, claimed ones too.
func stored_in(storage: int) -> int:
	return _stored.get(storage, 0)


## How many units in [param storage] nobody has claimed.
func free_in(storage: int) -> int:
	return _stored.get(storage, 0) - _claimed.get(storage, 0)


## How many more units [param storage] can take. A unit that is on its way to
## the storage already takes its place.
func room_in(storage: int) -> int:
	if not _kinds.has(storage):
		return 0
	return _capacities[storage] - _stored[storage] - _coming[storage]


## Changes the three counts of [param storage]: the units in it, the units in
## it that are claimed, and the units on their way to it. Returns false, and
## changes nothing, when a count would drop below zero, more would be claimed
## than is there, or more would be there and coming than fits.
func change(storage: int, stored_by: int, claimed_by: int, coming_by: int) -> bool:
	if not _kinds.has(storage):
		return false
	var stored := _stored[storage] + stored_by
	var claimed := _claimed[storage] + claimed_by
	var coming := _coming[storage] + coming_by
	if stored < 0 or claimed < 0 or coming < 0:
		return false
	if claimed > stored or stored + coming > _capacities[storage]:
		return false
	var kind := _kinds[storage]
	_stored[storage] = stored
	_claimed[storage] = claimed
	_coming[storage] = coming
	_stored_totals[kind] = _stored_totals.get(kind, 0) + stored_by
	_claimed_totals[kind] = _claimed_totals.get(kind, 0) + claimed_by
	return true


## How many units of [param kind] all storages together can hold.
func capacity_total(kind: int) -> int:
	return _capacity_totals.get(kind, 0)


## How many units of [param kind] are in all storages together.
func stored_total(kind: int) -> int:
	return _stored_totals.get(kind, 0)


## How many units of [param kind] in all storages nobody has claimed.
func free_total(kind: int) -> int:
	return _stored_totals.get(kind, 0) - _claimed_totals.get(kind, 0)


## The storage of [param kind] closest to [param point] that holds a unit
## nobody has claimed, or [constant NO_STORAGE]. It looks at every storage:
## storages are few.
func closest_free(kind: int, point: Vector2) -> int:
	var best := NO_STORAGE
	var best_distance := INF
	for storage: int in _kinds:
		if _kinds[storage] != kind or _stored[storage] <= _claimed[storage]:
			continue
		var distance := point.distance_squared_to(_spots[storage])
		if distance < best_distance:
			best_distance = distance
			best = storage
	return best


## The ids of all storages, in the order they were added.
func ids() -> PackedInt32Array:
	return PackedInt32Array(_kinds.keys())


## Forgets every storage.
func clear() -> void:
	for table: Dictionary in [_kinds, _spots, _capacities, _stored, _claimed, _coming]:
		table.clear()
	for table: Dictionary in [_capacity_totals, _stored_totals, _claimed_totals]:
		table.clear()


## The storages as plain data.
func snapshot() -> Dictionary:
	return {
		"kinds": _kinds.duplicate(),
		"spots": _spots.duplicate(),
		"capacities": _capacities.duplicate(),
		"stored": _stored.duplicate(),
		"claimed": _claimed.duplicate(),
		"coming": _coming.duplicate(),
	}
