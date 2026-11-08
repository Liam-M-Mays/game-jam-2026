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
	_pop()
	_refresh()
	Inventory.set_claimed(drop, false)

func take(drop : ResourceDrop) -> void:
	_held.erase(drop)
	drop.storage = null
	_refresh()

func first_unclaimed() -> ResourceDrop:
	for drop in _held:
		if not drop.claimed:
			return drop
	return null

func has_room() -> bool:
	return _held.size() + _en_route < capacity()

func make_store_job(drop : ResourceDrop) -> StoreJob:
	_en_route += 1
	return StoreJob.new(drop, self)

func idle_job_ended() -> void:
	_en_route -= 1

func _refresh() -> void:
	if capacity() <= 0:
		frame = last_stage()
		return
	_show_frame(last_stage() + ceili(float(_held.size()) * _fill_frames() / capacity()))
