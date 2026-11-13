extends Job
class_name StoreJob

var site : Storage
var _drop : ResourceDrop
var _carrying := false
## Where the meeple was last sent for the drop, in the grid's space. It is sent again only when the drop moves.
var _aimed := Vector2.INF

func _init(target_drop : ResourceDrop, target_site : Storage) -> void:
	_drop = target_drop
	site = target_site
	Inventory.set_claimed(_drop, true)

## Only once it carries the drop: before that it walks to the drop.
func goes_to(building : Building) -> bool:
	return _carrying and site == building

func start(worker : Meeple) -> void:
	_aim(worker)

func update(worker : Meeple, _delta : float) -> bool:
	if not is_instance_valid(site) or site.is_queued_for_deletion():
		abort(worker)
		return true
	if not _carrying:
		if _drop.position != _aimed:
			_aim(worker)
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

func _aim(worker : Meeple) -> void:
	_aimed = _drop.position
	worker.move_to(_drop.global_position)

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
