extends Node

signal changed

## The shortest time between two `changed`, in milliseconds. Thousands of working meeples change
## the stock almost every frame, and every HUD label and building site listens.
const CHANGED_EVERY_MS := 150
## The food numbers, shared with Population: start stock and the food cap with no silo.
var rules : VillageRules = preload("res://assets/Res/village_rules.tres")
## The side of a bucket of drops, in cells.
const DROP_AREA_CELLS := 2

var _drops := {}
var _all_drops : Array[ResourceDrop] = []
## Drops on the ground that nothing has claimed, per kind.
var _loose : Dictionary[String, int] = {}
var _stored : Dictionary = rules.start_stock.duplicate()
var _reserved := {}
## Drops kept in piles, drops on their way to a pile, and how many of those hauls have claimed, per kind.
var _piled : Dictionary[String, int] = {}
var _heading : Dictionary[String, int] = {}
var _pile_claims : Dictionary[String, int] = {}
var _dirty := false
var _last_changed := -CHANGED_EVERY_MS
## An AreaIndex of the loose drops per kind, in the grid's space, so the nearest one is found
## without checking them all.
var _areas : Dictionary[String, AreaIndex] = {}
var _grid : Grid

func _ready() -> void:
	process_priority = 100

## Runs after the game's nodes, so `changed` fires once with every change since the last time.
func _process(_delta : float) -> void:
	var now := Time.get_ticks_msec()
	if _dirty and now - _last_changed >= CHANGED_EVERY_MS:
		_dirty = false
		_last_changed = now
		changed.emit()

## Asks for `changed` at the end of this frame, or a little later when it fired a moment ago.
## However often it is called, `changed` fires once.
func mark_changed() -> void:
	_dirty = true

func reset() -> void:
	_stored = rules.start_stock.duplicate()
	_reserved.clear()
	_piled.clear()
	_heading.clear()
	_pile_claims.clear()
	mark_changed()

## Every drop of `kind` there is, claimed or not: on the ground, carried, in piles and in stock.
## What the player can spend is `available`.
func count(kind : String) -> int:
	return _drops_of(kind).size() + _piled.get(kind, 0) + _stored.get(kind, 0)

func food_cap() -> int:
	var cap := rules.base_food_cap
	for silo in get_tree().get_nodes_in_group(Silo.GROUP):
		cap += silo.food_capacity
	return cap

## How much of `kind` the finished piles can hold. Drops on the ground can take "have" above it.
func room(kind : String) -> int:
	var total := 0
	for pile : Storage in get_tree().get_nodes_in_group(Storage.GROUP):
		if pile.kind == kind:
			total += pile.capacity()
	return total

func food_full() -> bool:
	return count("food") >= food_cap()

func add(kind : String, amount : int) -> void:
	var total : int = _stored.get(kind, 0) + amount
	_stored[kind] = mini(total, food_cap()) if kind == "food" else total
	mark_changed()

func spend(kind : String, amount : int) -> void:
	if amount <= 0:
		return
	var have : int = _stored.get(kind, 0)
	_stored[kind] = maxi(have - amount, 0)
	mark_changed()

func register(drop : ResourceDrop) -> void:
	_grid = drop.grid
	_drops_of(drop.kind).append(drop)
	_all_drops.append(drop)
	_count_loose(drop, 1)
	mark_changed()

func unregister(drop : ResourceDrop) -> void:
	# Already gone: consumed before, or forgotten when the grid left.
	if not drop.is_in_world():
		return
	_drops_of(drop.kind).erase(drop)
	_all_drops.erase(drop)
	_count_loose(drop, -1)
	mark_changed()

## Forgets every drop and frees what they draw. The grid calls this when it leaves the game.
func clear_drops() -> void:
	for drop in _all_drops:
		drop.listed = false
		drop.free_item()
	_all_drops.clear()
	_areas.clear()
	_drops.clear()
	_loose.clear()
	mark_changed()

## A pile tells this when its stock, its claims or the drops on their way to it change.
func pile_changed(kind : String, stock : int, claims : int, heading := 0) -> void:
	_piled[kind] = _piled.get(kind, 0) + stock
	_pile_claims[kind] = _pile_claims.get(kind, 0) + claims
	_heading[kind] = _heading.get(kind, 0) + heading
	mark_changed()

## Every drop in the world: on the ground, or carried. Drops in piles are counts.
func all_drops() -> Array[ResourceDrop]:
	return _all_drops

## What the player can still spend: the HUD shows it, and placing and the build menu check it.
## Drops a site or a job has claimed are not in it. Drops on their way to a pile are, because a haul
## can claim them from that pile.
func available(kind : String) -> int:
	var in_piles : int = _piled.get(kind, 0) + _heading.get(kind, 0) - _pile_claims.get(kind, 0)
	return _stored.get(kind, 0) + _loose.get(kind, 0) + in_piles - _reserved.get(kind, 0)

func reserve(kind : String, amount : int) -> void:
	_reserved[kind] = _reserved.get(kind, 0) + amount

## Claims the closest drop of `kind` for a haul that reserved one.
## Returns the loose drop, or the pile when the closest is in a pile.
func claim_closest(kind : String, world_pos : Vector2) -> Object:
	var closest : Object = null
	var nearest := INF
	var drop := nearest_loose(kind, world_pos)
	if drop != null:
		closest = drop
		nearest = world_pos.distance_squared_to(drop.global_position)
	for pile : Storage in get_tree().get_nodes_in_group(Storage.GROUP):
		if pile.kind != kind or pile.unclaimed() <= 0:
			continue
		var distance := world_pos.distance_squared_to(pile.global_position)
		if distance < nearest:
			nearest = distance
			closest = pile
	_reserved[kind] -= 1
	if closest is Storage:
		(closest as Storage).claim()
	else:
		_claim(closest as ResourceDrop, true)
	return closest

## True when any drop lies on the ground with nothing claiming it.
func has_loose() -> bool:
	for kind in _loose:
		if _loose[kind] > 0:
			return true
	return false

## The loose drop of `kind` nearest to `from`, or null when none is loose.
func nearest_loose(kind : String, from : Vector2) -> ResourceDrop:
	if _loose.get(kind, 0) <= 0:
		return null
	var local := _grid.to_local(from)
	return _area_of(kind).best(local, func(drop : ResourceDrop) -> float:
		return INF if drop.claimed else local.distance_squared_to(drop.position),
		func(away : float) -> float: return away * away)

## A loose drop moved, in the grid's space. Its bucket follows it.
func drop_moved(drop : ResourceDrop, from : Vector2, to : Vector2) -> void:
	_area_of(drop.kind).move(drop, from, to)

func _area_of(kind : String) -> AreaIndex:
	if not _areas.has(kind):
		_areas[kind] = AreaIndex.new(_grid.area_size(DROP_AREA_CELLS))
	return _areas[kind]

func set_claimed(drop : ResourceDrop, on : bool) -> void:
	_claim(drop, on)
	mark_changed()

func _claim(drop : ResourceDrop, on : bool) -> void:
	var counted := drop.is_in_world()
	if counted:
		_count_loose(drop, -1)
	drop.claimed = on
	if counted:
		_count_loose(drop, 1)

## Adds `sign` to the loose count of `drop`'s kind when nothing has claimed it, and puts the drop in
## or takes it out of the search area of its kind.
func _count_loose(drop : ResourceDrop, sign : int) -> void:
	if drop.claimed:
		return
	_loose[drop.kind] = _loose.get(drop.kind, 0) + sign
	if sign > 0 and not drop.listed:
		_area_of(drop.kind).add(drop, drop.position)
	elif sign < 0 and drop.listed:
		_area_of(drop.kind).remove(drop, drop.position)
	drop.listed = sign > 0

func _drops_of(kind : String) -> Array:
	return _drops.get_or_add(kind, [])
