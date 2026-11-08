extends Building
class_name Storage

@export var kind := "stone"
@export var max_items := 0

var _held : Array[ResourceDrop] = []

func capacity() -> int:
	return max_items if max_items > 0 else _fill_frames()

func _fill_frames() -> int:
	return hframes - (last_stage() + 1)

func held() -> int:
	return _held.size()

func complete() -> void:
	super()
	_refresh()

func store(drop : ResourceDrop) -> void:
	drop.storage = self
	drop.global_position = global_position
	drop.hide()
	_held.append(drop)
	_refresh()
	Inventory.set_claimed(drop, false)

func take(drop : ResourceDrop) -> void:
	_held.erase(drop)
	drop.storage = null
	_refresh()

func has_idle_work(_worker : Meeple) -> bool:
	return _held.size() < capacity() and Inventory.available(kind) > 0 \
		and Inventory.closest_loose(kind, global_position) != null

func _make_idle_job(worker : Meeple) -> IdleJob:
	if not has_idle_work(worker):
		return null
	return StoreJob.new(Inventory.closest_loose(kind, worker.global_position))

func _refresh() -> void:
	if capacity() <= 0:
		frame = last_stage()
		return
	frame = last_stage() + ceili(float(_held.size()) * _fill_frames() / capacity())
