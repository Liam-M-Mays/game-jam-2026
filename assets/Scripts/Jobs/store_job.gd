extends Job
class_name StoreJob

var site : Storage
## The meeple on this trip, from `start`.
var meeple : Meeple
var _drop : ResourceDrop
var _carrying := false
## Where the meeple was last sent for the drop, in the grid's space. It is sent again only when the drop moves.
var _aimed := Vector2.INF

func _init(target_drop : ResourceDrop, target_site : Storage) -> void:
	_drop = target_drop
	site = target_site
	Inventory.set_claimed(_drop, true)

func start(by : Meeple) -> void:
	meeple = by
	JobSystem.store_trip_started(self)
	_aim(by)

## The kind of drop this trip carries.
func kind() -> String:
	return _drop.kind

## True once the meeple has picked the drop up.
func carrying() -> bool:
	return _carrying

## Where the drop is now: in the meeple's hands, or still on the ground.
func spot() -> Vector2:
	return meeple.global_position if _carrying else _drop.global_position

## A haul for a building site takes this trip's drop, picked up or not. The trip ends before it reaches
## the pile, and the meeple goes on as that haul.
func hand_over() -> ResourceDrop:
	var drop := _drop
	_drop = null
	JobSystem.store_trip_ended(self)
	site.trip_ended()
	return drop

func update(worker : Meeple, _delta : float) -> bool:
	if not is_instance_valid(site) or not site.is_in_group(Storage.GROUP):
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
	JobSystem.store_trip_ended(self)
	_drop = null
	_carrying = false
	return true

func _aim(worker : Meeple) -> void:
	_aimed = _drop.position
	worker.move_to(_drop.global_position)

## Puts the drop down. A haul that counted on it reaching the pile may take it from the ground.
func abort(worker : Meeple) -> void:
	if _drop == null:
		return
	var drop := _drop
	_drop = null
	JobSystem.store_trip_ended(self)
	if _carrying:
		drop.global_position = worker.global_position
		drop.show()
		worker.carry()
		_carrying = false
	Inventory.set_claimed(drop, false)
	if is_instance_valid(site):
		site.trip_dropped(drop)
