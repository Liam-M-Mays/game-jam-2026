extends Building
class_name Storage

const GROUP := &"storages"

@export var kind := "stone"
@export var max_items := 0

## Drops kept here are a number, not nodes. `_claimed` of them are promised to hauls.
var _stock := 0
var _claimed := 0
var _en_route := 0

func capacity() -> int:
	return max_items if max_items > 0 else _fill_frames()

func _fill_frames() -> int:
	return hframes - (last_stage() + 1)

func _icon_frame() -> int:
	return last_stage() + _fill_frames()

func held() -> int:
	return _stock

## Drops here that no haul has claimed yet.
func unclaimed() -> int:
	return _stock - _claimed

func complete() -> void:
	super()
	add_to_group(GROUP)
	Inventory.mark_changed()
	_refresh()

func store(drop : ResourceDrop) -> void:
	drop.consume()
	_stock += 1
	Inventory.pile_changed(kind, 1, 0)
	VillageAudio.play(&"log", global_position)
	_pop()
	_refresh()

## A haul claims one drop here. It picks it up later with `take`, or lets go with `unclaim`.
func claim() -> void:
	_claimed += 1
	Inventory.pile_changed(kind, 0, 1)

## Gives back a claim on a drop here, when the haul that made it is cancelled.
func unclaim() -> void:
	_claimed -= 1
	Inventory.pile_changed(kind, 0, -1)

## A haul picks up the drop it claimed. It gets a hidden drop to carry, as it does from the ground,
## so the stock count stays the same until the drop is delivered.
func take() -> ResourceDrop:
	_stock -= 1
	_claimed -= 1
	Inventory.pile_changed(kind, -1, -1)
	_refresh()
	var drop := grid.add_drop(ResourceDrop.scene_of(kind), grid.to_local(global_position))
	Inventory.set_claimed(drop, true)
	drop.hide()
	return drop

## A removed pile drops what it held. A haul that claimed a drop here takes one of the spilled drops instead.
func remove_building() -> void:
	var hauls := JobSystem.hauls_from(self)
	var spill : Dictionary[String, int] = {kind: _stock}
	Inventory.pile_changed(kind, -_stock, -_claimed)
	_stock = 0
	_claimed = 0
	super()
	var spilled := _pop_out(spill)
	for i in range(mini(hauls.size(), spilled.size())):
		hauls[i].take_spilled(spilled[i])

func has_room() -> bool:
	return _stock + _en_route < capacity()

## A trip for a free builder: the loose drop nearest to it, carried to the nearest pile of its kind
## that has room. Null when no drop lies loose or no pile has room for one.
static func find_trip(builder : Meeple) -> StoreJob:
	if not Inventory.has_loose():
		return null
	var piles := builder.grid.get_tree().get_nodes_in_group(GROUP)
	var from := builder.global_position
	var drop : ResourceDrop = null
	var looked : Array[String] = []
	for pile : Storage in piles:
		if looked.has(pile.kind) or not pile.has_room():
			continue
		looked.append(pile.kind)
		var near := Inventory.nearest_loose(pile.kind, from)
		if near != null and (drop == null or from.distance_squared_to(near.global_position) < from.distance_squared_to(drop.global_position)):
			drop = near
	if drop == null:
		return null
	var best : Storage = null
	var best_dist := INF
	for pile : Storage in piles:
		if pile.kind != drop.kind or not pile.has_room():
			continue
		var dist := drop.global_position.distance_squared_to(pile.global_position)
		if dist < best_dist:
			best_dist = dist
			best = pile
	return best.make_store_job(drop)

func make_store_job(drop : ResourceDrop) -> StoreJob:
	_en_route += 1
	return StoreJob.new(drop, self)

## A store job made by `make_store_job` ended, delivered or not, so its drop no longer counts against the room.
func trip_ended() -> void:
	_en_route -= 1

func _refresh() -> void:
	if capacity() <= 0:
		frame = last_stage()
		return
	_show_frame(last_stage() + ceili(float(_stock) * _fill_frames() / capacity()))
