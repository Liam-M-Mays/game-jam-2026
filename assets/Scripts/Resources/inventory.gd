extends Node

signal changed

var _drops := { "wood": [], "stone": [] }
var _reserved := { "wood": 0, "stone": 0 }

var wood : int:
	get:
		return _drops["wood"].size()
var stone : int:
	get:
		return _drops["stone"].size()

func register(drop : ResourceDrop) -> void:
	_drops[drop.kind].append(drop)
	changed.emit()

func unregister(drop : ResourceDrop) -> void:
	_drops[drop.kind].erase(drop)
	changed.emit()

func available(kind : String) -> int:
	var unclaimed := 0
	for drop in _drops[kind]:
		if not drop.claimed:
			unclaimed += 1
	return unclaimed - _reserved[kind]

func reserve(kind : String, amount : int) -> void:
	_reserved[kind] += amount

func claim_closest(kind : String, world_pos : Vector2) -> ResourceDrop:
	var closest : ResourceDrop = null
	for drop in _drops[kind]:
		if drop.claimed:
			continue
		if closest == null or world_pos.distance_squared_to(drop.global_position) < world_pos.distance_squared_to(closest.global_position):
			closest = drop
	closest.claimed = true
	_reserved[kind] -= 1
	return closest
