extends Node

signal changed

var _drops := {}
var _stored := {}
var _reserved := {}

func reset() -> void:
	_stored.clear()
	_reserved.clear()
	changed.emit()

func count(kind : String) -> int:
	return _drops_of(kind).size() + _stored.get(kind, 0)

func add(kind : String, amount : int) -> void:
	_stored[kind] = _stored.get(kind, 0) + amount
	changed.emit()

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
	closest.claimed = true
	_reserved[kind] -= 1
	return closest

func _drops_of(kind : String) -> Array:
	return _drops.get_or_add(kind, [])
