extends Job
class_name StoreJob

var site : Storage
var _drop : ResourceDrop
var _carrying := false

func _init(target_drop : ResourceDrop, target_site : Storage) -> void:
	_drop = target_drop
	site = target_site
	Inventory.set_claimed(_drop, true)

func start(worker : Meeple) -> void:
	worker.move_to(_drop.global_position)

func update(worker : Meeple, _delta : float) -> bool:
	if not is_instance_valid(site) or site.is_queued_for_deletion():
		abort(worker)
		return true
	if not _carrying:
		worker.move_to(_drop.global_position)
		if not worker.has_arrived():
			return false
		_carrying = true
		_drop.hide()
		worker.carry(_drop.kind)
		worker.move_to(site.global_position, site.cells)
		return false
	if not worker.has_arrived():
		return false
	worker.carry()
	site.store(_drop)
	site.trip_ended()
	_drop = null
	_carrying = false
	return true

func abort(worker : Meeple) -> void:
	if _drop == null:
		return
	if is_instance_valid(site):
		site.trip_ended()
	if _carrying:
		_drop.global_position = worker.global_position
		_drop.show()
		worker.carry()
		_carrying = false
	Inventory.set_claimed(_drop, false)
	_drop = null
