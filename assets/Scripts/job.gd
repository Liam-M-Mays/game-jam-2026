extends RefCounted
class_name Job

# Called once when a meeple picks up the job.
func start(_worker : Meeple) -> void:
	pass

# Called every frame until it returns true, which means the job is finished.
func update(_worker : Meeple, _delta : float) -> bool:
	return true
