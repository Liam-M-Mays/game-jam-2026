extends GameTest
## Checks the saved recipe of the ground world: the band table, the amounts
## of the jam map, and the numbers of the start. Also the world seed.

const JAM_GREEN := Color(0.3922, 0.6, 0.3843)


func test_the_band_table_has_a_dark_and_a_light_band() -> void:
	var recipe := WorldRecipe.load_recipe()
	check_eq(recipe.bands.size(), 2)
	var dark := recipe.bands[0]
	var light := recipe.bands[1]
	check_eq(dark.band_name, &"dark")
	check_eq(light.band_name, &"light")
	check_near(dark.share + light.share, 1.0)
	check_near(dark.share, 0.25)
	check_eq(dark.kinds, [&"big_tree", &"big_rock"] as Array[StringName])
	check_eq(light.kinds, [&"tree", &"rock", &"bush"] as Array[StringName])
	check(dark.colour.get_luminance() < light.colour.get_luminance(), "dark is the darker colour")


func test_the_amounts_are_the_targets_of_the_jam_map() -> void:
	var recipe := WorldRecipe.load_recipe()
	check_eq(recipe.amount_cells, 2091)
	check_eq(recipe.amounts.get(&"tree"), 60)
	check_eq(recipe.amounts.get(&"rock"), 60)
	check_eq(recipe.amounts.get(&"big_tree"), 34)
	check_eq(recipe.amounts.get(&"bush"), 15)
	check_eq(recipe.amounts.get(&"big_rock"), 36)
	check_eq(recipe.amounts.size(), 5)


func test_an_amount_grows_with_the_world() -> void:
	var recipe := WorldRecipe.load_recipe()
	check_eq(recipe.amount_for(&"tree", 2091), 60)
	check_eq(recipe.amount_for(&"tree", 100000), 2869)
	check_eq(recipe.amount_for(&"rock", 100000), 2869)
	check_eq(recipe.amount_for(&"big_tree", 100000), 1626)
	check_eq(recipe.amount_for(&"bush", 100000), 717)
	check_eq(recipe.amount_for(&"big_rock", 100000), 1722)
	check_eq(recipe.amount_for(&"cactus", 100000), 0, "a kind with no amount gets none")


func test_a_band_is_found_by_its_ground_kind() -> void:
	var recipe := WorldRecipe.load_recipe()
	check_eq(WorldRecipe.ground_of(0), 1)
	check_eq(WorldRecipe.ground_of(1), 2)
	check_eq(recipe.band_of(1), recipe.bands[0])
	check_eq(recipe.band_of(2), recipe.bands[1])
	check(recipe.band_of(0) == null, "ground kind 0 is no cell")
	check(recipe.band_of(3) == null, "the table has two bands")
	check(recipe.allows(1, &"big_tree"), "a big tree may stand in the dark")
	check(not recipe.allows(2, &"big_tree"), "but not in the light")
	check(recipe.allows(2, &"bush"), "a bush may stand in the light")
	check(not recipe.allows(1, &"bush"), "but not in the dark")
	check(not recipe.allows(0, &"tree"), "nothing stands where there is no cell")


func test_the_start_is_the_town_hall_of_the_jam_game() -> void:
	var recipe := WorldRecipe.load_recipe()
	check_eq(recipe.start_width, 2)
	check_eq(recipe.start_depth, 1)
	check_eq(recipe.start_clear_steps, 1)
	check_eq(recipe.ground_colour, JAM_GREEN, "the flat ground is the jam game's base green")


func test_a_fixed_seed_is_kept() -> void:
	check_eq(WorldSeed.pick(1234), 1234)
	check_eq(WorldSeed.pick(-7), -7)


func test_no_fixed_seed_gives_a_new_seed_each_time() -> void:
	var picked: Dictionary[int, bool] = {}
	for index in 20:
		var world_seed := WorldSeed.pick(WorldSeed.RANDOM)
		check(world_seed >= 1 and world_seed <= WorldSeed.HIGHEST, "in range: %d" % world_seed)
		picked[world_seed] = true
	check(picked.size() >= 19, "20 new games got %d different seeds" % picked.size())


func test_the_seed_line_is_the_jam_games() -> void:
	check_eq(WorldSeed.line(42), "World seed: 42")
	check_eq(DevSettings.new().world_seed, WorldSeed.RANDOM, "no seed is fixed by default")


func test_nothing_drawn_shows_the_jam_teal() -> void:
	var colour: Color = ProjectSettings.get_setting(
		"rendering/environment/defaults/default_clear_color"
	)
	check(colour.is_equal_approx(Color(0.3231953, 0.46788818, 0.45547175, 1.0)), str(colour))
