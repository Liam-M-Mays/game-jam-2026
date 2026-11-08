extends Resource
class_name BuildFrame

@export var costs : Dictionary[String, int] = {}

func total() -> int:
	var sum := 0
	for kind in costs:
		sum += costs[kind]
	return sum
