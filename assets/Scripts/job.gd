extends RefCounted
class_name Job

func start(_worker : Meeple) -> void:
	pass

func update(_worker : Meeple, _delta : float) -> bool:
	return true
