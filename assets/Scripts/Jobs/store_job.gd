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

func carried() -> Array[ResourceDrop]:
	var drops : Array[ResourceDrop] = []
	if _carrying and _drop != null:
		drops.append(_drop)
	return drops

## What a save keeps of this trip, with buildings and loose drops as indexes. Empty when it cannot be put back.
func saved(index_of : Dictionary, drop_index : Dictionary) -> Dictionary:
	if _drop == null or not index_of.has(site):
		return {}
	if not _carrying and not drop_index.has(_drop):
		return {}
	return {"type": "store", "pile": index_of[site], "kind": _drop.kind, "carrying": _carrying, "drop": drop_index.get(_drop, -1)}

## Puts back a store trip from a save on `worker`: carrying a drop of `kind` to `pile`, or walking to the loose
## `drop`. False when the pile is gone or full, or the drop is.
static func resume_saved(worker : Meeple, pile : Storage, kind : String, carrying : bool, drop : ResourceDrop) -> bool:
	if pile == null or not pile.is_in_group(Storage.GROUP) or not pile.has_room():
		return false
	if carrying:
		drop = worker.grid.add_drop(ResourceDrop.scene_of(kind), worker.position)
	elif drop == null:
		return false
	var trip := pile.make_store_job(drop)
	trip._carrying = carrying
	JobSystem.resume(trip, worker)
	return true

## Starts a trip put back from a save, as it was: carrying to its pile, or walking to its drop.
func resume(by : Meeple) -> void:
	meeple = by
	JobSystem.store_trip_started(self)
	if _carrying:
		_drop.hide()
		by.carry(_drop.kind)
		by.move_to(site.global_position, site.cells)
	else:
		_aim(by)

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
