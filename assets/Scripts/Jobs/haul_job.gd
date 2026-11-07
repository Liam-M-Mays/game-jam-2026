extends Job
class_name HaulJob

var site : building
var kind : String
var _drop : ResourceDrop

func _init(target_site : building, target_kind : String) -> void:
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
		worker.set_carrying(kind)
		worker.move_to(site.global_position)
		return false
	if not worker.has_arrived():
		return false
	worker.clear_carrying()
	site.deliver()
	return true
