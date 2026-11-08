extends IdleJob
class_name StoreJob

var _drop : ResourceDrop
var _carrying := false

func _init(target_drop : ResourceDrop) -> void:
	_drop = target_drop
	Inventory.set_claimed(_drop, true)

func start(worker : Meeple) -> void:
	worker.move_to(_drop.global_position)

func update(worker : Meeple, _delta : float) -> bool:
	if not is_instance_valid(site):
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
	(site as Storage).store(_drop)
	_drop = null
	_carrying = false
	return true

func abort(worker : Meeple) -> void:
	if _drop == null:
		return
	if _carrying:
		_drop.global_position = worker.global_position
		_drop.show()
		worker.carry()
		_carrying = false
	Inventory.set_claimed(_drop, false)
	_drop = null
