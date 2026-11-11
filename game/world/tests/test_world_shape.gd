extends GameTest
## Checks the shape of a generated world: the same seed gives the same world,
## it has about the cells that were asked for, it is round with an uneven
## edge, and it is in one piece with no hole in it.

## How many slices the world is cut into to measure how far its edge reaches.
const SLICES := 24
## How many seeds the one-piece tests try, at each world size.
const PIECE_SEEDS := 40


func test_the_same_seed_gives_the_same_world() -> void:
	var first := WorldTestKit.village(7)
	var second := WorldTestKit.village(7)
	check(first.snapshot() == second.snapshot(), "two worlds from seed 7 are the same")
	check_eq(first.state_hash(), second.state_hash())
	var world := GroundWorld.of(first)
	var wanted := 0
	for kind_name: StringName in world.wanted:
		wanted += world.wanted[kind_name]
	check(wanted > 150, "the world wants things: %d" % wanted)
	check_eq(world.thing_count(), wanted, "every thing the world wants was placed")
	check_eq(first.grid.cell_count(), world.cells, "the cells are in the grid")


func test_another_seed_gives_another_world() -> void:
	var first := WorldTestKit.village(7)
	var second := WorldTestKit.village(8)
	check(first.snapshot() != second.snapshot(), "seed 7 and seed 8 differ")
	check(first.grid.snapshot() != second.grid.snapshot(), "their grids differ")
	var one := GroundWorld.of(first)
	var two := GroundWorld.of(second)
	check(one.thing_cells != two.thing_cells, "their things stand elsewhere")
	check(one.bounds != two.bounds, "their outlines differ: %s and %s" % [one.bounds, two.bounds])


func test_a_world_has_about_the_cells_asked_for() -> void:
	for asked: int in [500, 2000, 8000]:
		for world_seed in range(1, 6):
			var made := WorldTestKit.village(world_seed, asked)
			var world := GroundWorld.of(made)
			check_eq(world.asked_cells, asked)
			check_eq(made.grid.cell_count(), world.cells)
			var off := absi(world.cells - asked)
			check(off <= asked / 50, "seed %d: asked %d, got %d" % [world_seed, asked, world.cells])


func test_the_world_is_round_and_not_a_leaning_box() -> void:
	for world_seed in range(1, 6):
		var made := WorldTestKit.village(world_seed)
		var world := GroundWorld.of(made)
		var size := world.bounds.size
		var aspect := size.x / size.y
		check(aspect > 0.88 and aspect < 1.14, "as wide as tall: %.2f" % aspect)
		var fill := world.cells * WorldGenerator.CELL_AREA / (size.x * size.y)
		check(fill > 0.68 and fill < 0.88, "fills its box like a disc: %.2f" % fill)
		var wobble := world.recipe.edge_wobble
		var cell_reach := float(GridLayout.CELL_WIDTH)
		for cell in WorldTestKit.cells_of(made):
			var far := GridLayout.position_of(cell).length()
			if far > world.radius * (1.0 + wobble) + cell_reach:
				fail("cell %s is outside the outer circle" % cell)
				break
		var inner := world.radius * (1.0 - wobble) - cell_reach
		for step in 200:
			var point := Vector2.from_angle(step * 0.7) * inner * (step / 200.0)
			if made.grid.cell_at(point) == GridLayout.NO_CELL:
				fail("the point %s inside the inner circle has no cell" % point)
				break


func test_the_edge_is_uneven() -> void:
	for world_seed in range(1, 6):
		var spread := _edge_spread(WorldTestKit.village(world_seed, 8000))
		check(spread > 0.05, "seed %d: the edge moves in and out: %.3f" % [world_seed, spread])


func test_no_wobble_gives_a_plain_circle() -> void:
	var recipe := WorldTestKit.recipe()
	recipe.edge_wobble = 0.0
	var spread := _edge_spread(WorldTestKit.village(3, 8000, recipe))
	check(spread < 0.03, "with no wobble the edge is a circle: %.3f" % spread)


func test_every_cell_can_be_reached_from_the_start() -> void:
	for cells: int in [500, WorldTestKit.CELLS]:
		for world_seed in range(1, PIECE_SEEDS + 1):
			var made := WorldTestKit.village(world_seed, cells)
			var cut_off := _cells_cut_off(made)
			check_eq(cut_off, 0, "seed %d, %d cells: cells cut off from the start" % [world_seed, cells])


func test_a_world_is_one_piece_up_to_the_roughest_edge() -> void:
	var recipe := WorldTestKit.recipe()
	recipe.edge_wobble = WorldRecipe.MOST_EDGE_WOBBLE
	recipe.edge_bumps = WorldRecipe.MOST_EDGE_BUMPS
	for cells: int in [500, WorldTestKit.CELLS]:
		for world_seed in range(1, PIECE_SEEDS + 1):
			var made := WorldTestKit.village(world_seed, cells, recipe)
			var cut_off := _cells_cut_off(made)
			check_eq(cut_off, 0, "seed %d, %d cells: cells cut off from the start" % [world_seed, cells])
			check_eq(_holes(made), 0, "seed %d, %d cells: holes of one cell" % [world_seed, cells])


func test_a_village_gets_one_world_only() -> void:
	var made := WorldTestKit.village(4)
	var world := GroundWorld.of(made)
	var cells := made.grid.cell_count()
	check(WorldGenerator.generate(made, 500) == null, "a second world is refused")
	check_eq(GroundWorld.of(made), world)
	check_eq(made.grid.cell_count(), cells, "the grid was not touched")
	var closed := Village.new(4, 20)
	closed.close()
	check(WorldGenerator.generate(closed, 500) == null, "a closed village gets no world")


func test_a_village_with_cells_gets_no_world() -> void:
	var made := Village.new(4, 20)
	made.grid.add_cell(Vector2i.ZERO)
	check(WorldGenerator.generate(made, 500) == null, "a grid that has a cell is refused")
	check_eq(made.grid.cell_count(), 1, "the grid was not touched")
	check(GroundWorld.of(made) == null, "and no world hangs on the village")


func test_a_world_of_no_cells_is_refused() -> void:
	for asked: int in [0, -10]:
		var made := Village.new(4, 20)
		var before := made.snapshot()
		check(WorldGenerator.generate(made, asked) == null, "%d cells are refused" % asked)
		check(GroundWorld.of(made) == null, "no world hangs on the village")
		check(made.snapshot() == before, "and the village was not touched")


func test_a_closed_village_lets_go_of_its_world() -> void:
	var made := WorldTestKit.village(4)
	var world := GroundWorld.of(made)
	made.close()
	check_eq(world.thing_count(), 0)
	check_eq(world.keep_clear.size(), 0)
	check(world.recipe == null, "the recipe was let go")
	check(not world.is_kept_clear(world.start_cell), "nothing is kept clear any more")


## How many cells of [param made] have no path of neighbours to the start cell.
func _cells_cut_off(made: Village) -> int:
	var world := GroundWorld.of(made)
	var seen: Dictionary[Vector2i, bool] = {world.start_cell: true}
	var queue: Array[Vector2i] = [world.start_cell]
	var next := 0
	while next < queue.size():
		for near in made.grid.neighbours(queue[next]):
			if not seen.has(near):
				seen[near] = true
				queue.append(near)
		next += 1
	return world.cells - seen.size()


## How many holes of one cell [param made] has: a place with no cell whose
## six neighbours all exist. A hole of two or more cells is not counted.
func _holes(made: Village) -> int:
	var first := Vector2i.ZERO
	var last := Vector2i.ZERO
	for cell in WorldTestKit.cells_of(made):
		first = first.min(cell)
		last = last.max(cell)
	var holes := 0
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			if not made.grid.has_cell(cell) and made.grid.neighbours(cell).size() == 6:
				holes += 1
	return holes


## How much further the edge reaches in its longest slice than in its
## shortest, as a share of the radius.
func _edge_spread(made: Village) -> float:
	var world := GroundWorld.of(made)
	var reach := PackedFloat32Array()
	reach.resize(SLICES)
	for cell in WorldTestKit.cells_of(made):
		var at := GridLayout.position_of(cell)
		var slice := int(fposmod(at.angle(), TAU) / TAU * SLICES) % SLICES
		reach[slice] = maxf(reach[slice], at.length())
	var shortest := INF
	var longest := 0.0
	for far in reach:
		shortest = minf(shortest, far)
		longest = maxf(longest, far)
	return (longest - shortest) / world.radius
