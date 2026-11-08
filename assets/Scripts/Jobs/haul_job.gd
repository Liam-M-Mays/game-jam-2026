extends Job
class_name HaulJob

var site : Building
var kind : String
var _drop : ResourceDrop
var _carrying := false
var _partner : HaulJob

func _init(target_site : Building, target_kind : String) -> void:
	site = target_site
	kind = target_kind

func start(worker : Meeple) -> void:
	_drop = Inventory.claim_closest(kind, worker.global_position)
	if _drop.storage != null:
		_grab_partner()

func update(worker : Meeple, _delta : float) -> bool:
	if not _carrying:
		var stop : Array[Cell] = []
		if _drop.storage != null:
			stop = _drop.storage.cells
		worker.move_to(_drop.global_position, stop)
		if not worker.has_arrived():
			return false
		_pick_up()
		if _partner != null:
			_partner._pick_up()
		worker.carry(kind, 2 if _partner != null else 1)
		worker.move_to(site.global_position, site.cells)
		return false
	if not worker.has_arrived():
		return false
	_deliver()
	if _partner != null:
		_partner._deliver()
		JobSystem.finish(_partner)
		_partner = null
	worker.carry()
	return true

func abort(worker : Meeple) -> void:
	if _partner != null:
		var partner := _partner
		_partner = null
		JobSystem.requeue(partner, worker)
	if _drop == null:
		return
	if _carrying:
		_drop.global_position = worker.global_position
		_drop.show()
		worker.carry()
		_carrying = false
	Inventory.release(_drop)
	_drop = null

func _grab_partner() -> void:
	var extra := _drop.storage.first_unclaimed()
	if extra == null:
		return
	_partner = JobSystem.take_partner(self)
	if _partner == null:
		return
	_partner._drop = extra
	Inventory.claim_reserved(extra)

func _pick_up() -> void:
	_carrying = true
	if _drop.storage != null:
		_drop.storage.take(_drop)
	_drop.hide()

func _deliver() -> void:
	_drop.queue_free()
	_drop = null
	_carrying = false
	site.deliver(kind)
