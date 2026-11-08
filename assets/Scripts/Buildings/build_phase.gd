extends Resource
class_name BuildPhase

@export var costs : Dictionary[String, int] = {}
@export var frame := -1

func total() -> int:
	var sum := 0
	for kind in costs:
		sum += costs[kind]
	return sum
