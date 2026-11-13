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

## The worker carries a loose drop of this pile's kind to a pile of that kind.
## It picks the drop and the pile with the shortest total trip.
func find_work(worker : Meeple) -> Job:
	if Inventory.available(kind) <= 0:
		return null
	var from := worker.global_position
	var best_pile : Storage = null
	var best_drop : ResourceDrop = null
	var best_trip := INF
	for pile : Storage in get_tree().get_nodes_in_group(GROUP):
		if pile.kind != kind or not pile.has_room():
			continue
		var drop := Inventory.shortest_trip_loose(kind, from, pile.global_position)
		if drop == null:
			continue
		var trip := from.distance_to(drop.global_position) + drop.global_position.distance_to(pile.global_position)
		if trip < best_trip:
			best_trip = trip
			best_pile = pile
			best_drop = drop
	if best_pile == null:
		return null
	return best_pile.make_store_job(best_drop)

func make_store_job(drop : ResourceDrop) -> StoreJob:
	_en_route += 1
	return StoreJob.new(drop, self)

func trip_ended() -> void:
	_en_route -= 1

func _refresh() -> void:
	if capacity() <= 0:
		frame = last_stage()
		return
	_show_frame(last_stage() + ceili(float(_stock) * _fill_frames() / capacity()))
