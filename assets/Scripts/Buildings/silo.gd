extends BarnPlot
class_name Silo

const GROUP := &"silos"

@export var food_capacity := 20

func complete() -> void:
	super()
	add_to_group(GROUP)
	Inventory.mark_changed()
