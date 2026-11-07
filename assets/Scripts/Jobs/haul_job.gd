extends Job
class_name HaulJob

var site : Building
var kind : String
var _drop : ResourceDrop

func _init(target_site : Building, target_kind : String) -> void:
	site = target_site
	kind = target_kind

func start(worker : Meeple) -> void:
	_drop = Inventory.claim_closest(kind, worker.global_position)

func update(worker : Meeple, _delta : float) -> bool:
	if _drop != null:
		worker.move_to(_drop.global_position)
		if not worker.has_arrived():
			return false
		_drop.queue_free()
		_drop = null
		worker.carry(kind)
		worker.move_to(site.global_position, site.cells)
		return false
	if not worker.has_arrived():
		return false
	worker.carry()
	site.deliver()
	return true
