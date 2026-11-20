extends RefCounted
class_name Job

var cancelled := false

## Where the job is done, in world space. Jobs and meeples are matched by the distance to it.
func place() -> Vector2:
	return Vector2.ZERO

## True when the meeple doing this job walks to `building`. A moved building turns those meeples round.
func goes_to(_building : Building) -> bool:
	return false

func start(_worker : Meeple) -> void:
	pass

func update(_worker : Meeple, _delta : float) -> bool:
	return true

func abort(_worker : Meeple) -> void:
	pass
