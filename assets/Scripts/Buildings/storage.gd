extends Building
class_name Storage

const GROUP := &"storages"

@export var kind := "stone"
@export var max_items := 0

var _held : Array[ResourceDrop] = []
var _en_route := 0

func capacity() -> int:
	return max_items if max_items > 0 else _fill_frames()

func _fill_frames() -> int:
	return hframes - (last_stage() + 1)

func _icon_frame() -> int:
	return last_stage() + _fill_frames()

func held() -> int:
	return _held.size()

func complete() -> void:
	super()
	add_to_group(GROUP)
	_refresh()

func store(drop : ResourceDrop) -> void:
	drop.storage = self
	drop.global_position = global_position
	drop.hide()
	_held.append(drop)
	VillageAudio.play(&"log", global_position)
	_pop()
	_refresh()
	Inventory.set_claimed(drop, false)

func take(drop : ResourceDrop) -> void:
	_held.erase(drop)
	drop.storage = null
	_refresh()

func has_room() -> bool:
	return _held.size() + _en_route < capacity()

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
	_show_frame(last_stage() + ceili(float(_held.size()) * _fill_frames() / capacity()))
