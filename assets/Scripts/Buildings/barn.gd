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

## The whole plot area has to be on the ground, free of buildings, and kept for no other barn.
## Trees, rocks and bushes in it are cleared after placing. A barn being moved has its farms
## standing in its area, so it moves only onto clear land.
func can_place_at(at_grid : Grid, at_cells : Array[Cell]) -> bool:
	var area := area_at(at_grid, at_cells[0])
	var clears := clears_land()
	return super(at_grid, at_cells) and area.size() == plot_offsets.size() \
		and area.all(func(c : Cell): return (c.occupant == null or (clears and c.occupant is Standing)) \
			and (c.kept_for == null or c.kept_for == self))

func placement_hint() -> String:
	if not clears_land():
		return "A moved barn needs its plot area clear of trees, rocks, bushes and buildings, and not shared with another barn"
	return "A barn needs its plot area free of buildings and not shared with another barn"

## A new barn may go over trees, rocks and bushes. A finished one being moved may not.
func clears_land() -> bool:
	return not is_in_group(COMPLETED_GROUP)

## Keeps the plot area and marks what stands in it to be cleared, so farms and silos can be placed
## around the barn straight away, even while it waits for its own cells.
func put_down(at_grid : Grid, at_cells : Array[Cell]) -> void:
	add_to_group(GROUP)
	var area := area_at(at_grid, at_cells[0])
	for cell in area:
		cell.kept_for = self
	mark_land(at_grid, area)
	super(at_grid, at_cells)

func area_at(at_grid : Grid, anchor : Cell) -> Array[Cell]:
	return at_grid.cells_at_offsets(anchor, plot_offsets)

func build_after(_scene : PackedScene) -> PackedScene:
	return farm_scene

func note() -> String:
	var farms := plots.filter(func(p : BarnPlot) -> bool: return p is Farm).size()
	var silos := plots.filter(func(p : BarnPlot) -> bool: return p is Silo).size()
	return "Farms left: %d\nSilos left: %d" % [slots() - farms, slots() - silos]

## Farms and silos can go up next to a barn that is still being built.
func start_construction() -> void:
	add_to_group(GROUP)
	for cell in area_at(grid, cells[0]):
		cell.kept_for = self
	super()

## Farm land starts growing once the barn is finished.
func complete() -> void:
	add_to_group(GROUP)
	super()
	for plot in plots:
		if plot is Farm and plot.is_in_group(COMPLETED_GROUP):
			plot.start_growing()

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

## A clearing job on `cell` was cancelled: the farm or silo waiting there is not built, or the barn
## itself when the cell is one of its own.
func land_not_cleared(cell : Cell) -> void:
	var plot := plot_on(cell)
	if plot != null:
		plot.land_not_cleared(cell)
	else:
		super(cell)

## A barn that is not built takes its farms and silos with it. Those already started pop out what
## they cost, and the rest of its plot area is no longer cleared.
func cancel_waiting(say := true) -> void:
	for plot in plots.duplicate():
		if is_instance_valid(plot):
			if plot.is_waiting_for_land():
				plot.cancel_waiting(false)
			else:
				plot.remove_building()
	plots.clear()
	var area := area_at(grid, cells[0])
	for cell in area:
		if cell.kept_for == self:
			cell.kept_for = null
	_unmark_land(area)
	super(say)

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

## A barn whose farm or silo still waits for its land stays put until that land is cleared.
func can_move() -> bool:
	return super() and not plots.any(func(p : BarnPlot) -> bool: return p.is_waiting_for_land())

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

## The farm or silo on `cell`, or waiting for it to be cleared, or null.
func plot_on(cell : Cell) -> BarnPlot:
	for plot in plots:
		if is_instance_valid(plot) and plot.cells.has(cell):
			return plot
	return null

## The cells of the plot area a farm or silo can still go on. Trees, rocks and bushes there are cleared first.
func plot_area() -> Array[Cell]:
	var free : Array[Cell] = []
	for cell in area_at(grid, cells[0]):
		if cell.kept_for == self and (cell.occupant == null or cell.occupant is Standing) and plot_on(cell) == null:
			free.append(cell)
	return free

func in_plot_range(plot : Array[Cell]) -> bool:
	return plot.all(func(c : Cell): return c.kept_for == self and plot_on(c) == null)
