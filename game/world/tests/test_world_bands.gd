extends GameTest
## Checks the bands of a generated world: every cell has a band of the table,
## each band has its share, the bands follow the noise, and one seed drives
## the noise and the placing.


## Hears the errors the engine reports while it is switched on.
class Listener:
	extends Logger
	var errors: PackedStringArray = []

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		_error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		errors.append("%s %s" % [code, rationale])


func test_every_cell_has_a_band_of_the_table() -> void:
	var made := WorldTestKit.village(11)
	var world := GroundWorld.of(made)
	var dark := WorldTestKit.count_ground(made, WorldTestKit.DARK)
	var light := WorldTestKit.count_ground(made, WorldTestKit.LIGHT)
	check_eq(dark + light, world.cells, "every cell is dark or light")
	check(absi(dark - roundi(0.25 * world.cells)) <= 1, "a quarter is dark: %d" % dark)
	check_eq(world.recipe.band_of(WorldTestKit.DARK).band_name, &"dark")
	check_eq(world.recipe.band_of(WorldTestKit.LIGHT).band_name, &"light")


func test_the_bands_follow_the_noise() -> void:
	var world_seed := 11
	var made := WorldTestKit.village(world_seed)
	var noise := WorldGenerator.band_noise(world_seed, GroundWorld.of(made).recipe.area_cells)
	var darkest_light := INF
	var lightest_dark := -INF
	for cell in WorldTestKit.cells_of(made):
		var at := GridLayout.position_of(cell) + GridLayout.CELL_MIDDLE
		var value := noise.get_noise_2d(at.x, at.y)
		if made.grid.ground(cell) == WorldTestKit.DARK:
			lightest_dark = maxf(lightest_dark, value)
		else:
			darkest_light = minf(darkest_light, value)
	check(lightest_dark < darkest_light, "every dark cell is darker than every light cell")


func test_a_table_with_three_bands_cuts_three_shares() -> void:
	var recipe := WorldTestKit.recipe()
	var middle := WorldBand.new()
	middle.band_name = &"middle"
	recipe.bands.insert(1, middle)
	recipe.bands[0].share = 0.2
	recipe.bands[1].share = 0.3
	recipe.bands[2].share = 0.5
	var made := WorldTestKit.village(12, WorldTestKit.CELLS, recipe)
	var cells := GroundWorld.of(made).cells
	check(absi(WorldTestKit.count_ground(made, 1) - roundi(0.2 * cells)) <= 1, "dark is 20%")
	check(absi(WorldTestKit.count_ground(made, 2) - roundi(0.3 * cells)) <= 1, "middle is 30%")
	check(absi(WorldTestKit.count_ground(made, 3) - roundi(0.5 * cells)) <= 1, "light is 50%")
	check_eq(WorldTestKit.count_ground(made, 4), 0)


func test_a_table_with_too_many_bands_is_cut_and_says_so() -> void:
	var rows := WorldRecipe.MAX_BANDS + 1
	var recipe := WorldTestKit.recipe()
	recipe.bands.clear()
	for index in rows:
		var band := WorldBand.new()
		band.band_name = StringName("band_%d" % index)
		band.share = 1.0 / rows
		recipe.bands.append(band)
	var listener := Listener.new()
	OS.add_logger(listener)
	var made := WorldTestKit.village(12, WorldTestKit.CELLS, recipe)
	OS.remove_logger(listener)
	var said := false
	for line in listener.errors:
		said = said or line.contains("the band table has %d rows" % rows)
	check(said, "the generator reported the long table: %s" % [listener.errors])
	var cells := GroundWorld.of(made).cells
	var counted := 0
	for ground in range(1, WorldRecipe.MAX_BANDS + 1):
		counted += WorldTestKit.count_ground(made, ground)
	check_eq(counted, cells, "every cell is in one of the first %d bands" % WorldRecipe.MAX_BANDS)
	check_eq(WorldTestKit.count_ground(made, rows), 0, "no cell is in the row that was cut")


func test_the_noise_seeds_come_from_the_world_seed() -> void:
	check_eq(WorldGenerator.band_noise_seed(5), 5)
	check_eq(WorldGenerator.edge_noise_seed(5), 6)
	check_eq(WorldGenerator.band_noise_seed(0x100000005), 5, "cut to 31 bits")
	check_eq(WorldGenerator.edge_noise_seed(0x7FFFFFFF), 0, "the seed plus one, cut to 31 bits")
	check_eq(WorldGenerator.band_noise(5, 40.0).seed, 5)
	check_eq(WorldGenerator.edge_noise(5).seed, 6)


func test_the_placing_rolls_come_from_the_village() -> void:
	var plain := WorldTestKit.village(9)
	var rolled := Village.new(9, 20)
	rolled.rng.randi()
	WorldGenerator.generate(rolled, WorldTestKit.CELLS)
	var one := GroundWorld.of(plain)
	var two := GroundWorld.of(rolled)
	check_eq(two.cells, one.cells, "the shape only reads the seed")
	check_eq(two.start_cell, one.start_cell, "the start cell only reads the ground")
	var same_ground := true
	for cell in WorldTestKit.cells_of(plain):
		if plain.grid.ground(cell) != rolled.grid.ground(cell):
			same_ground = false
	check(same_ground, "the bands only read the seed")
	check(two.thing_cells != one.thing_cells, "the things follow the village's rolls")
	check_eq(two.placed, one.placed, "but there are as many of each kind")


func test_placing_uses_up_rolls_of_the_village() -> void:
	var fresh := RandomNumberGenerator.new()
	fresh.seed = 9
	var made := WorldTestKit.village(9)
	check(made.rng.state != fresh.state, "the village's random numbers moved on")
