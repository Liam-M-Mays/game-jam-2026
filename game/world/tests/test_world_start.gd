extends GameTest
## Checks the start cell: it is the lightest spot near the middle of the
## world, on light ground and away from the dark areas, it is chosen with no
## roll, and the cells round it are kept clear.

const SEEDS := 8


func test_the_cells_round_the_start_cell_are_empty() -> void:
	for world_seed in range(1, SEEDS + 1):
		var made := WorldTestKit.village(world_seed)
		var world := GroundWorld.of(made)
		check_eq(world.keep_clear.size(), 10, "2 start cells and the 8 round them")
		for cell in world.keep_clear:
			check(made.grid.has_cell(cell), "kept-clear cell %s exists" % cell)
			check_eq(made.grid.occupant(cell), VillageGrid.NOTHING, "cell %s is empty" % cell)
			check(world.is_kept_clear(cell), "cell %s says it is kept clear" % cell)


func test_the_kept_clear_cells_are_the_start_building_and_its_ring() -> void:
	var made := WorldTestKit.village(2)
	var world := GroundWorld.of(made)
	var start := world.start_cell
	check_eq(world.start_cells(), [start, start + Vector2i(1, 0)] as Array[Vector2i])
	var want: Array[Vector2i] = []
	for offset: Vector2i in [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(0, -1),
		Vector2i(1, -1), Vector2i(2, -1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	]:
		want.append(start + offset)
	var got := world.keep_clear.duplicate()
	want.sort()
	got.sort()
	check_eq(got, want)
	check(not world.is_kept_clear(start + Vector2i(3, 0)), "three steps along is not kept clear")
	check(not world.is_kept_clear(start + Vector2i(0, 2)), "two rows down is not kept clear")


func test_the_start_stays_clear_on_a_crowded_world() -> void:
	var recipe := WorldTestKit.recipe()
	recipe.amounts = {&"tree": 2000} as Dictionary[StringName, int]
	var made := WorldTestKit.village(3, WorldTestKit.CELLS, recipe)
	var world := GroundWorld.of(made)
	var light := WorldTestKit.count_ground(made, WorldTestKit.LIGHT)
	check_eq(world.placed[&"tree"], light - 10, "a tree on every light cell but the 10 kept clear")
	for cell in world.keep_clear:
		check_eq(made.grid.occupant(cell), VillageGrid.NOTHING, "cell %s is empty" % cell)


func test_the_start_is_on_light_ground_away_from_the_dark() -> void:
	for world_seed in range(1, SEEDS + 1):
		var made := WorldTestKit.village(world_seed)
		var world := GroundWorld.of(made)
		for cell in world.keep_clear:
			check_eq(made.grid.ground(cell), WorldTestKit.LIGHT, "cell %s is light" % cell)
		var reach := world.recipe.start_reach * world.radius
		var far := (GridLayout.position_of(world.start_cell) + GridLayout.CELL_MIDDLE).length()
		check(far <= reach, "seed %d: the start is near the middle" % world_seed)


func test_the_start_is_the_lightest_spot_that_fits() -> void:
	var world_seed := 6
	var made := WorldTestKit.village(world_seed)
	var world := GroundWorld.of(made)
	var noise := WorldGenerator.band_noise(world_seed, world.recipe.area_cells)
	var reach := world.recipe.start_reach * world.radius
	var start_at := GridLayout.position_of(world.start_cell) + GridLayout.CELL_MIDDLE
	var start_value := noise.get_noise_2d(start_at.x, start_at.y)
	var lighter := 0
	var looked_at := 0
	for cell in WorldTestKit.cells_of(made):
		var at := GridLayout.position_of(cell) + GridLayout.CELL_MIDDLE
		if at.length() > reach:
			continue
		looked_at += 1
		if noise.get_noise_2d(at.x, at.y) > start_value and _ring_is_light(made, cell):
			lighter += 1
	check(looked_at > 100, "cells near the middle were looked at: %d" % looked_at)
	check_eq(lighter, 0, "cells that fit and are lighter than the start cell")


func test_choosing_the_start_rolls_nothing() -> void:
	var made := Village.new(6, 20)
	var maker := WorldGenerator.new()
	maker.shape(6, WorldTestKit.CELLS)
	maker.cut_bands()
	maker.fill_grid(made.grid)
	var before := made.rng.state
	var ids_before := made.new_id()
	var grid_before := made.grid.snapshot()
	maker.choose_start()
	check_eq(made.rng.state, before, "no random number was taken")
	check_eq(made.new_id(), ids_before + 1, "no id was taken")
	check(made.grid.snapshot() == grid_before, "the grid was not touched")
	maker.place_things(made)
	var world := maker.finish(made)
	check_eq(world.start_cell, GroundWorld.of(WorldTestKit.village(6)).start_cell)


func test_a_world_with_no_fitting_spot_starts_in_the_middle() -> void:
	var recipe := WorldTestKit.recipe()
	recipe.bands[0].share = 1.0
	recipe.bands[1].share = 0.0
	var made := WorldTestKit.village(6, 500, recipe)
	var world := GroundWorld.of(made)
	check_eq(world.start_cell, Vector2i.ZERO, "an all-dark world starts on the middle cell")
	check_eq(world.keep_clear.size(), 10)


func test_a_start_needs_light_ground_all_round() -> void:
	var recipe := WorldTestKit.recipe()
	recipe.bands[0].share = 0.996
	recipe.bands[1].share = 0.004
	recipe.start_reach = 1.0
	var world_seed := 1
	var made := WorldTestKit.village(world_seed, WorldTestKit.CELLS, recipe)
	var world := GroundWorld.of(made)
	var light := WorldTestKit.count_ground(made, WorldTestKit.LIGHT)
	check(light > 0 and light < 10, "fewer light cells than the 10 a start takes: %d" % light)
	var noise := WorldGenerator.band_noise(world_seed, recipe.area_cells)
	var lightest := Vector2i.ZERO
	var lightest_value := -INF
	for cell in WorldTestKit.cells_of(made):
		var at := GridLayout.position_of(cell) + GridLayout.CELL_MIDDLE
		if noise.get_noise_2d(at.x, at.y) > lightest_value:
			lightest_value = noise.get_noise_2d(at.x, at.y)
			lightest = cell
	check(lightest != Vector2i.ZERO, "the lightest cell is not the middle cell")
	check_eq(made.grid.ground(lightest), WorldTestKit.LIGHT)
	for part in GridLayout.footprint(lightest, 2, 1):
		for offset in GridLayout.offsets_within(1):
			check(made.grid.has_cell(part + offset), "the ring round the lightest cell exists")
	check(not _ring_is_light(made, lightest), "but that ring is not light all round")
	check_eq(world.start_cell, Vector2i.ZERO, "so the world starts on its middle cell instead")


## True when the start building at [param cell] and its ring are all light.
func _ring_is_light(made: Village, cell: Vector2i) -> bool:
	for part in GridLayout.footprint(cell, 2, 1):
		for offset in GridLayout.offsets_within(1):
			if made.grid.ground(part + offset) != WorldTestKit.LIGHT:
				return false
	return true
