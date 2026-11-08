extends Building
class_name Barn

const GROUP := &"barns"

@export var max_farms := 3
@export var farm_radius := 3

var farms : Array[Farm] = []

func start_construction() -> void:
	add_to_group(GROUP)
	super()

func complete() -> void:
	add_to_group(GROUP)
	super()

func farm_count() -> int:
	var count := 0
	for farm in farms:
		if is_instance_valid(farm):
			count += 1
	return count

func has_farm_room() -> bool:
	return farm_count() < max_farms

func add_farm(farm : Farm) -> void:
	farms.append(farm)

func farm_area() -> Array[Cell]:
	return grid.cells_around(self, farm_radius)

func in_farm_range(plot : Array[Cell]) -> bool:
	for cell in plot:
		var near := false
		for own in cells:
			if grid.cell_distance(cell, own) <= farm_radius:
				near = true
				break
		if not near:
			return false
	return true
