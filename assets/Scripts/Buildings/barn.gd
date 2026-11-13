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

## What placing this barn goes on to place.
@export var farm_scene : PackedScene

var plots : Array[BarnPlot] = []

## The whole plot area has to be on the ground, clear, and kept for no other barn.
func can_place_at(at_grid : Grid, at_cells : Array[Cell]) -> bool:
	var area := area_at(at_grid, at_cells[0])
	return super(at_grid, at_cells) and area.size() == plot_offsets.size() \
		and area.all(func(c : Cell): return c.occupant == null and (c.kept_for == null or c.kept_for == self))

func placement_hint() -> String:
	return "A barn needs its plot area clear of trees, rocks, bushes and buildings, and not shared with another barn"

func area_at(at_grid : Grid, anchor : Cell) -> Array[Cell]:
	return at_grid.cells_at_offsets(anchor, plot_offsets)

func build_after(_scene : PackedScene) -> PackedScene:
	return farm_scene

func note() -> String:
	var farms := plots.filter(func(p): return p is Farm).size()
	var silos := plots.filter(func(p): return p is Silo).size()
	return "Farms left: %d\nSilos left: %d" % [slots() - farms, slots() - silos]

## Farms and silos can go up next to a barn that is still being built.
func start_construction() -> void:
	add_to_group(GROUP)
	for cell in area_at(grid, cells[0]):
		cell.kept_for = self
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

## The barn's worker harvests the ripe farm nearest to it.
func find_work(worker : Meeple) -> Job:
	var from := worker.global_position
	var best : Farm = null
	for plot in plots:
		if not is_instance_valid(plot) or not plot is Farm or not plot.can_harvest_now():
			continue
		if best == null or from.distance_squared_to(plot.global_position) < from.distance_squared_to(best.global_position):
			best = plot
	return FarmJob.new(best) if best != null else null

func remove_question() -> String:
	return "Remove this Barn and its farms and silos?" if not plots.is_empty() else super()

## A barn takes its farms and silos with it, and their cost pops out too.
func remove_building() -> void:
	for plot in plots.duplicate():
		if is_instance_valid(plot):
			plot.remove_building()
	plots.clear()
	for cell in area_at(grid, cells[0]):
		if cell.kept_for == self:
			cell.kept_for = null
	super()

## A moved barn lifts its farms and silos too, so its whole plot area moves as one shape.
func lift() -> void:
	super()
	for plot in plots:
		plot.lift()

## Each farm and silo keeps its place in the plot area, and the kept cells move with the barn.
func land(at_cells : Array[Cell]) -> void:
	var old_area := area_at(grid, cells[0])
	super(at_cells)
	var new_area := area_at(grid, cells[0])
	for cell in old_area:
		cell.kept_for = null
	for cell in new_area:
		cell.kept_for = self
	for plot in plots:
		plot.land([new_area[old_area.find(plot.cells[0])]])

func add_plot(plot : BarnPlot) -> void:
	plots.append(plot)

func plot_area() -> Array[Cell]:
	var free : Array[Cell] = []
	for cell in area_at(grid, cells[0]):
		if cell.occupant == null and cell.kept_for == self:
			free.append(cell)
	return free

func in_plot_range(plot : Array[Cell]) -> bool:
	return plot.all(func(c : Cell): return c.kept_for == self)
