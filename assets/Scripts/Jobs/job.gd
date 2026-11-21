extends RefCounted
class_name Job

var cancelled := false

## Where the job is done, in world space. Jobs and meeples are matched by the distance to it.
func place() -> Vector2:
	return Vector2.ZERO

func start(_worker : Meeple) -> void:
	pass

## The drops the meeple on this job holds right now.
func carried() -> Array[ResourceDrop]:
	return []

## Starts a job put back from a save. Most jobs just start again.
func resume(worker : Meeple) -> void:
	start(worker)

func update(_worker : Meeple, _delta : float) -> bool:
	return true

func abort(_worker : Meeple) -> void:
	pass
