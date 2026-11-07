extends RefCounted
class_name Job

var cancelled := false

func start(_worker : Meeple) -> void:
	pass

func update(_worker : Meeple, _delta : float) -> bool:
	return true
