extends Node

signal changed
signal shortage(kind : String, missing : int)

const START_STOCK := { "food": 10 }
const BASE_FOOD_CAP := 20

var _drops := {}
var _stored := START_STOCK.duplicate()
var _reserved := {}

func reset() -> void:
	_stored = START_STOCK.duplicate()
	_reserved.clear()
	changed.emit()

func count(kind : String) -> int:
	return _drops_of(kind).size() + _stored.get(kind, 0)

func food_cap() -> int:
	var cap := BASE_FOOD_CAP
	for silo in get_tree().get_nodes_in_group(Silo.GROUP):
		cap += silo.food_capacity
	return cap

func food_full() -> bool:
	return count("food") >= food_cap()

func add(kind : String, amount : int) -> void:
	var total : int = _stored.get(kind, 0) + amount
	_stored[kind] = mini(total, food_cap()) if kind == "food" else total
	changed.emit()

func spend(kind : String, amount : int) -> void:
	if amount <= 0:
		return
	var have : int = _stored.get(kind, 0)
	_stored[kind] = maxi(have - amount, 0)
	changed.emit()
	if amount > have:
		shortage.emit(kind, amount - have)

func register(drop : ResourceDrop) -> void:
	_drops_of(drop.kind).append(drop)
	changed.emit()

func unregister(drop : ResourceDrop) -> void:
	_drops_of(drop.kind).erase(drop)
	changed.emit()

func available(kind : String) -> int:
	var unclaimed := _drops_of(kind).filter(func(drop): return not drop.claimed).size()
	return unclaimed - _reserved.get(kind, 0)

func reserve(kind : String, amount : int) -> void:
	_reserved[kind] = _reserved.get(kind, 0) + amount

func claim_closest(kind : String, world_pos : Vector2) -> ResourceDrop:
	var closest : ResourceDrop = null
	for drop in _drops_of(kind):
		if drop.claimed:
			continue
		if closest == null or world_pos.distance_squared_to(drop.global_position) < world_pos.distance_squared_to(closest.global_position):
			closest = drop
	claim_reserved(closest)
	return closest

func claim_reserved(drop : ResourceDrop) -> void:
	drop.claimed = true
	_reserved[drop.kind] -= 1

func closest_loose(kind : String, world_pos : Vector2) -> ResourceDrop:
	var closest : ResourceDrop = null
	for drop in _drops_of(kind):
		if drop.claimed or drop.storage != null:
			continue
		if closest == null or world_pos.distance_squared_to(drop.global_position) < world_pos.distance_squared_to(closest.global_position):
			closest = drop
	return closest

func set_claimed(drop : ResourceDrop, on : bool) -> void:
	drop.claimed = on
	changed.emit()

func release(drop : ResourceDrop) -> void:
	drop.claimed = false
	_reserved[drop.kind] = _reserved.get(drop.kind, 0) + 1
	changed.emit()

func _drops_of(kind : String) -> Array:
	return _drops.get_or_add(kind, [])
