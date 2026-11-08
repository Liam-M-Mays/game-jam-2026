extends Building
class_name Barn

const GROUP := &"barns"

@export var base_slots := 3
@export var plot_offsets : Array[Vector2i] = [
	Vector2i(0, -2), Vector2i(1, -2),
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
	Vector2i(-1, 0), Vector2i(2, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(0, 2), Vector2i(1, 2),
]

var plots : Array[BarnPlot] = []

func start_construction() -> void:
	add_to_group(GROUP)
	super()

func complete() -> void:
	add_to_group(GROUP)
	super()

func slots() -> int:
	var total := base_slots
	for windmill in get_tree().get_nodes_in_group(Windmill.GROUP):
		total += windmill.extra_barn_slots
	return total

func plot_count(plot : BarnPlot) -> int:
	var count := 0
	for other in plots:
		if is_instance_valid(other) and other.get_script() == plot.get_script():
			count += 1
	return count

func has_room_for(plot : BarnPlot) -> bool:
	return plot_count(plot) < slots()

func add_plot(plot : BarnPlot) -> void:
	plots.append(plot)

func plot_area() -> Array[Cell]:
	var free : Array[Cell] = []
	for cell in grid.cells_at_offsets(cells[0], plot_offsets):
		if cell.occupant == null:
			free.append(cell)
	return free

func in_plot_range(plot : Array[Cell]) -> bool:
	var allowed := grid.cells_at_offsets(cells[0], plot_offsets)
	for cell in plot:
		if not allowed.has(cell):
			return false
	return true
