extends Resource
class_name BuildPhase

## Resources hauled during this phase. The next phase starts once all of them arrive.
@export var costs : Dictionary[String, int] = {}
## Build stage the sprite reaches when this phase is done. Counted from the empty
## plot (0), the same way whether or not the sheet is reversed. -1 = finished.
@export var frame := -1

func total() -> int:
	var sum := 0
	for kind in costs:
		sum += costs[kind]
	return sum
