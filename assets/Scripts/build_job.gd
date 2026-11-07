extends Job
class_name BuildJob

var site : building

func _init(target_site : building) -> void:
	site = target_site

func start(worker : Meeple) -> void:
	worker.move_to(site.global_position)

func update(worker : Meeple, _delta : float) -> bool:
	if not worker.has_arrived():
		return false
	site.finish_build()
	return true
