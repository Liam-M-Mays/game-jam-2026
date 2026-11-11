class_name StockClaims
extends RefCounted
## Who is promised what from the stock of a village.
##
## There are two promises, as in the jam game:
## - A reservation: a building site is promised a number of units of a kind,
##   but no unit in particular yet.
## - A claim: a hauler is promised one unit in particular, a drop on the
##   ground or a unit in a pile. Nobody else can claim that unit, so two
##   haulers never go for the same item.
##
## Both are made by an id, never by an object: the id of the site, and the id
## of the haul. Reach this as [member VillageStock.claims].
##
## A haul to a building site: [method reserve], then [method claim_closest]
## turns one reservation into a claim, then [method pick_up], then
## [method hand_over]. A trip to a storage: [method claim_for_storage], then
## [method pick_up], then [method hand_over]. At any point [method release]
## gives the unit back.
##
## A site that ends has to do it in this order: first [method release] every
## haul that works for it, then [method unreserve] what is left. A released
## haul always gives its reservation back to the site, so the other order
## leaves the site with a reservation it no longer wants.
##
## A loose drop can also be taken off the ground without the stock, with
## [method GridDrops.remove] or [method GridDrops.take]. The claims hear that.
## When more is reserved than is left, the newest site loses reservations
## until the two agree again: see [method available]. A claimed drop that was
## taken that way is found out by [method pick_up] and [method release].

## A number of a kind changed: what is free, reserved, claimed, carried or
## stored. A change on the ground is told by [GridDrops] instead.
signal changed(kind: int)

## The id that means nobody.
const NOBODY := 0

const _KIND := 0
const _RESERVER := 1
const _CARRIED := 2
const _DROP := 3
const _SOURCE := 4
const _TARGET := 5

var _drops: GridDrops
var _storages: StockStorages
var _reserved: Dictionary[int, Dictionary] = {}
var _reserved_totals: Dictionary[int, int] = {}
var _claims: Dictionary[int, PackedInt32Array] = {}
var _spots: Dictionary[int, Vector2] = {}
var _carried: Dictionary[int, int] = {}


func _init(drops: GridDrops, storages: StockStorages) -> void:
	_drops = drops
	_storages = storages
	_drops.removed.connect(_on_drop_removed)


## How many units of [param kind] can still be promised: the loose drops and
## the unclaimed units in piles, minus what is reserved.
##
## [method reserve] refuses more than this. And when a loose drop is taken off
## the ground with [method GridDrops.take] or [method GridDrops.remove] while
## every unit is reserved, a reservation goes with it: the site with the
## highest id, which is the newest one, loses first. That site has to ask
## again: read [method reserved_by] when [signal VillageStock.changed] comes.
## A unit that a hauler has claimed already is not taken back, so an older
## site can lose its reservation before a newer one.
##
## So this is not below zero, with two exceptions:
## - A unit taken out of a pile with [method StockStorages.change] is not
##   heard here. After such a call this can be below zero, until the next
##   drop leaves the ground.
## - A listener that was put on [signal GridDrops.removed] before the stock
##   was hung on the village hears a taken drop before the claims do, and can
##   read a number below zero. Listen to [signal VillageStock.changed].
func available(kind: int) -> int:
	if _drops == null:
		return 0
	return _drops.loose(kind) + _storages.free_total(kind) - _reserved_totals.get(kind, 0)


## Reserves [param amount] units of [param kind] for the site
## [param reserver]. Returns false, and reserves nothing, when fewer than
## that are available.
func reserve(reserver: int, kind: int, amount: int = 1) -> bool:
	if reserver <= NOBODY or amount <= 0 or available(kind) < amount:
		return false
	_change_reserved(reserver, kind, amount)
	changed.emit(kind)
	return true


## Gives back up to [param amount] units of [param kind] that
## [param reserver] had reserved. Returns how many were given back. A unit
## that a hauler has claimed already is not given back by this: release the
## haul first.
func unreserve(reserver: int, kind: int, amount: int = 1) -> int:
	var given := mini(amount, reserved_by(reserver, kind))
	if given <= 0:
		return 0
	_change_reserved(reserver, kind, -given)
	changed.emit(kind)
	return given


## How many units of [param kind] are reserved for [param reserver] now. A
## unit that a hauler has claimed is no longer counted here.
func reserved_by(reserver: int, kind: int) -> int:
	var mine: Dictionary = _reserved.get(reserver, {})
	return mine.get(kind, 0)


## The haul [param claimer] claims the unclaimed unit of [param kind] closest
## to [param point], whether it lies on the ground or sits in a pile. That
## turns one reservation of [param reserver] into a claim. Returns false when
## the claimer already has a claim, the reserver has no reservation of that
## kind, or no unit is left.
func claim_closest(claimer: int, reserver: int, kind: int, point: Vector2) -> bool:
	if _drops == null or claimer <= NOBODY or _claims.has(claimer):
		return false
	if reserved_by(reserver, kind) <= 0:
		return false
	var drop := _drops.closest(kind, point)
	var storage := _storages.closest_free(kind, point)
	if drop != GridDrops.NO_DROP and storage != StockStorages.NO_STORAGE:
		var to_drop := point.distance_squared_to(_drops.spot_of(drop))
		if point.distance_squared_to(_storages.spot_of(storage)) < to_drop:
			drop = GridDrops.NO_DROP
	if drop != GridDrops.NO_DROP:
		_drops.claim(drop, claimer)
		_spots[claimer] = _drops.spot_of(drop)
		storage = StockStorages.NO_STORAGE
	elif storage != StockStorages.NO_STORAGE:
		_storages.change(storage, 0, 1, 0)
		_spots[claimer] = _storages.spot_of(storage)
	else:
		return false
	_claims[claimer] = PackedInt32Array([kind, reserver, 0, drop, storage, 0])
	_change_reserved(reserver, kind, -1)
	changed.emit(kind)
	return true


## The trip [param claimer] claims the loose [param drop] to carry it to
## [param storage]. The drop is locked from now on: it still counts in the
## stock, but it cannot be promised to a site. Returns false when the claimer
## already has a claim, the drop is not loose or of another kind, the storage
## has no room, or every loose unit of the kind is reserved.
func claim_for_storage(claimer: int, storage: int, drop: int) -> bool:
	if _drops == null or claimer <= NOBODY or _claims.has(claimer):
		return false
	var kind := _drops.kind_of(drop)
	if kind == GridDrops.NO_KIND or kind != _storages.kind_of(storage):
		return false
	if _drops.claimer_of(drop) != NOBODY or _storages.room_in(storage) <= 0:
		return false
	if available(kind) <= 0:
		return false
	_drops.claim(drop, claimer)
	_storages.change(storage, 0, 0, 1)
	_spots[claimer] = _drops.spot_of(drop)
	_claims[claimer] = PackedInt32Array([kind, NOBODY, 0, drop, 0, storage])
	changed.emit(kind)
	return true


## The claimed unit of [param claimer] is picked up: it leaves the ground or
## the pile and is carried. It still counts in the stock. Returns false when
## there is no claim or the unit is carried already.
##
## It also returns false when the claimed drop no longer lies on the ground
## for this claimer: somebody took it without the stock. Then the claim ends
## here, nothing is carried, and the site gets no reservation back, because
## the unit is gone. The site has to reserve again.
func pick_up(claimer: int) -> bool:
	if not _claims.has(claimer) or _claims[claimer][_CARRIED] == 1:
		return false
	var claim := _claims[claimer]
	var kind := claim[_KIND]
	if _lost_its_drop(claimer, claim):
		_end_lost_claim(claimer, claim)
		return false
	_carried[kind] = _carried.get(kind, 0) + 1
	claim[_CARRIED] = 1
	if claim[_DROP] != GridDrops.NO_DROP:
		var drop := claim[_DROP]
		claim[_DROP] = GridDrops.NO_DROP
		_claims[claimer] = claim
		# The ground tells the change.
		_drops.remove(drop, claimer)
		return true
	_storages.change(claim[_SOURCE], -1, -1, 0)
	claim[_SOURCE] = StockStorages.NO_STORAGE
	_claims[claimer] = claim
	changed.emit(kind)
	return true


## The carried unit of [param claimer] arrives. On a haul it goes into the
## building site and leaves the stock. On a trip to a storage it lands in the
## pile. The claim ends. Returns false when the unit is not carried.
func hand_over(claimer: int) -> bool:
	if not _claims.has(claimer) or _claims[claimer][_CARRIED] == 0:
		return false
	var claim := _claims[claimer]
	var kind := claim[_KIND]
	if claim[_TARGET] != StockStorages.NO_STORAGE:
		_storages.change(claim[_TARGET], 1, 0, -1)
	_carried[kind] -= 1
	_forget(claimer)
	changed.emit(kind)
	return true


## Ends the claim of [param claimer] without a delivery. A unit that was not
## picked up yet is simply free again. A carried unit is put on the ground at
## [param spot], or where it was picked up when no cell is under the spot. On
## a haul the reservation of the site is restored, also when the site has
## given back everything else in the meantime. Returns false when there is no
## claim.
##
## It also returns false when the claimed drop no longer lies on the ground
## for this claimer: somebody took it without the stock. Then the claim ends,
## and no reservation is restored, because the unit is gone.
func release(claimer: int, spot: Vector2) -> bool:
	if not _claims.has(claimer):
		return false
	var claim := _claims[claimer]
	var kind := claim[_KIND]
	if _lost_its_drop(claimer, claim):
		_end_lost_claim(claimer, claim)
		return false
	var origin: Vector2 = _spots[claimer]
	_forget(claimer)
	if claim[_TARGET] != StockStorages.NO_STORAGE:
		_storages.change(claim[_TARGET], 0, 0, -1)
	if claim[_RESERVER] != NOBODY:
		_change_reserved(claim[_RESERVER], kind, 1)
	if claim[_CARRIED] == 1:
		_carried[kind] -= 1
		# The ground tells the change.
		if _drops.add_at(spot, kind) == GridDrops.NO_DROP:
			_drops.add_at(origin, kind)
		return true
	if claim[_DROP] != GridDrops.NO_DROP:
		_drops.unclaim(claim[_DROP])
	else:
		_storages.change(claim[_SOURCE], 0, -1, 0)
	changed.emit(kind)
	return true


## True when [param claimer] holds a claim.
func has(claimer: int) -> bool:
	return _claims.has(claimer)


## Where the claimed unit of [param claimer] is to be picked up, in art
## pixels: the spot of the drop, or the spot of the pile.
func spot_of(claimer: int) -> Vector2:
	return _spots.get(claimer, Vector2.ZERO)


## The pile the claimed unit of [param claimer] sits in, or
## [constant StockStorages.NO_STORAGE] when it lies on the ground or is carried.
func storage_of(claimer: int) -> int:
	return _claims[claimer][_SOURCE] if _claims.has(claimer) else StockStorages.NO_STORAGE


## The drop on the ground that [param claimer] has claimed, or
## [constant GridDrops.NO_DROP] when the unit sits in a pile or is carried.
func drop_of(claimer: int) -> int:
	return _claims[claimer][_DROP] if _claims.has(claimer) else GridDrops.NO_DROP


## True when [param claimer] carries its unit.
func is_carried(claimer: int) -> bool:
	return _claims.has(claimer) and _claims[claimer][_CARRIED] == 1


## How many units of [param kind] are being carried.
func carried(kind: int) -> int:
	return _carried.get(kind, 0)


## Lets go of the ground, the storages and every promise.
func close() -> void:
	if _drops != null:
		_drops.removed.disconnect(_on_drop_removed)
	_drops = null
	_storages = null
	_reserved.clear()
	_reserved_totals.clear()
	_claims.clear()
	_spots.clear()
	_carried.clear()


## The promises as plain data.
func snapshot() -> Dictionary:
	var claims := {}
	for claimer: int in _claims:
		claims[claimer] = _claims[claimer].duplicate()
	return {
		"reserved": _reserved.duplicate(true),
		"claims": claims,
		"spots": _spots.duplicate(),
		"carried": _carried.duplicate(),
	}


## Runs when a drop left the ground. A loose drop that was taken without the
## stock can leave more reserved than there is: then the newest sites lose
## reservations until the two agree. A drop that a hauler picks up was
## claimed, so it leaves nothing to settle, unless a unit was taken out of a
## pile with [method StockStorages.change] before: then this drop, picked up
## or not, costs the newest site a reservation. Nothing is told here, the
## stock tells that the drop left.
func _on_drop_removed(_drop: int, kind: int) -> void:
	var too_many := -available(kind)
	if too_many <= 0:
		return
	var reservers := _reserved.keys()
	reservers.sort()
	reservers.reverse()
	for reserver: int in reservers:
		var lost := mini(too_many, reserved_by(reserver, kind))
		if lost > 0:
			_change_reserved(reserver, kind, -lost)
			too_many -= lost
		if too_many <= 0:
			return


## True when [param claim] is for a drop on the ground, and that drop is no
## longer there for [param claimer]: it was taken, or its row now holds
## another drop.
func _lost_its_drop(claimer: int, claim: PackedInt32Array) -> bool:
	var drop := claim[_DROP]
	if drop == GridDrops.NO_DROP:
		return false
	return _drops.claimer_of(drop) != claimer or _drops.kind_of(drop) != claim[_KIND]


## Ends a claim whose drop is gone. The site gets no reservation back. A
## place that was kept in a pile for the unit is free again.
func _end_lost_claim(claimer: int, claim: PackedInt32Array) -> void:
	_forget(claimer)
	if claim[_TARGET] != StockStorages.NO_STORAGE:
		_storages.change(claim[_TARGET], 0, 0, -1)
		changed.emit(claim[_KIND])


func _change_reserved(reserver: int, kind: int, by: int) -> void:
	var mine: Dictionary = _reserved.get(reserver, {})
	mine[kind] = mine.get(kind, 0) + by
	if mine[kind] <= 0:
		mine.erase(kind)
	if mine.is_empty():
		_reserved.erase(reserver)
	else:
		_reserved[reserver] = mine
	_reserved_totals[kind] = _reserved_totals.get(kind, 0) + by


func _forget(claimer: int) -> void:
	_claims.erase(claimer)
	_spots.erase(claimer)
