extends Building
class_name Barn

const GROUP := &"barns"

@export var max_farms := 3
@export var farm_offsets : Array[Vector2i] = [
	Vector2i(0, -2), Vector2i(1, -2),
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
	Vector2i(-1, 0), Vector2i(2, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(0, 2), Vector2i(1, 2),
]

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
	var free : Array[Cell] = []
	for cell in grid.cells_at_offsets(cells[0], farm_offsets):
		if cell.occupant == null:
			free.append(cell)
	return free

func in_farm_range(plot : Array[Cell]) -> bool:
	var allowed := grid.cells_at_offsets(cells[0], farm_offsets)
	for cell in plot:
		if not allowed.has(cell):
			return false
	return true
