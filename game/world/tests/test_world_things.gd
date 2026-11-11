extends GameTest
## Checks the trees, rocks and bushes of a generated world: each stands on a
## band that allows it in the band table, there are as many of each kind as
## the table says, and a full band ends the placing.

## What Liam's list says a world of 100,000 cells holds, by kind (issue #48).
const AMOUNTS_AT_100000: Dictionary[StringName, int] = {
	&"tree": 2870, &"rock": 2870, &"big_tree": 1630, &"bush": 720, &"big_rock": 1720,
}
## The list is rounded to tens, and the real world is a few cells off 100,000.
const ABOUT := 10


func test_every_thing_stands_on_a_band_that_allows_it() -> void:
	for world_seed in range(1, 5):
		var made := WorldTestKit.village(world_seed)
		var world := GroundWorld.of(made)
		check(world.thing_count() > 150, "the world has things: %d" % world.thing_count())
		for row in world.thing_count():
			var kind_name := world.thing_kind(row).kind_name
			for cell in made.grid.thing_cells(world.thing_ids[row]):
				if not world.recipe.allows(made.grid.ground(cell), kind_name):
					fail("seed %d: a %s stands on cell %s" % [world_seed, kind_name, cell])


func test_big_ones_stand_in_the_dark_and_small_ones_in_the_light() -> void:
	var made := WorldTestKit.village(2)
	var world := GroundWorld.of(made)
	var seen: Dictionary[StringName, int] = {}
	for row in world.thing_count():
		var kind_name := world.thing_kind(row).kind_name
		var big := kind_name == &"big_tree" or kind_name == &"big_rock"
		var want := WorldTestKit.DARK if big else WorldTestKit.LIGHT
		for cell in made.grid.thing_cells(world.thing_ids[row]):
			check_eq(made.grid.ground(cell), want, "%s on cell %s" % [kind_name, cell])
		seen[kind_name] = seen.get(kind_name, 0) + 1
	check_eq(seen.size(), 5, "all five kinds stand on the world")


func test_the_things_follow_a_changed_band_table() -> void:
	var recipe := WorldTestKit.recipe()
	recipe.bands[0].kinds = [&"tree"] as Array[StringName]
	recipe.bands[1].kinds = [&"big_rock"] as Array[StringName]
	var made := WorldTestKit.village(2, WorldTestKit.CELLS, recipe)
	var world := GroundWorld.of(made)
	check_eq(world.placed[&"tree"], world.wanted[&"tree"])
	check_eq(world.placed[&"big_rock"], world.wanted[&"big_rock"])
	check_eq(world.placed[&"rock"], 0, "no band allows a rock now")
	check_eq(world.placed[&"bush"], 0)
	check_eq(world.placed[&"big_tree"], 0)
	for row in world.thing_count():
		var tree := world.thing_kind(row).kind_name == &"tree"
		var want := WorldTestKit.DARK if tree else WorldTestKit.LIGHT
		for cell in made.grid.thing_cells(world.thing_ids[row]):
			check_eq(made.grid.ground(cell), want)


func test_the_amounts_on_a_world_of_100000_cells() -> void:
	var made := WorldTestKit.village(1, 100000)
	var world := GroundWorld.of(made)
	check(absi(world.cells - 100000) <= 500, "about 100,000 cells: %d" % world.cells)
	var total := 0
	for kind_name: StringName in AMOUNTS_AT_100000:
		var placed := world.placed[kind_name]
		total += placed
		check_eq(placed, world.wanted[kind_name], "every %s that is wanted was placed" % kind_name)
		check_eq(placed, world.recipe.amount_for(kind_name, world.cells), "the share of %s" % kind_name)
		check_eq(WorldTestKit.count_rows(world, kind_name), placed, "the rows of %s" % kind_name)
		var listed := AMOUNTS_AT_100000[kind_name]
		var off := absi(placed - listed)
		check(off <= ABOUT, "%s: %d, the list says %d" % [kind_name, placed, listed])
	check_eq(world.thing_count(), total)
	check_eq(world.placed.size(), 5)


func test_a_thing_takes_every_cell_of_its_footprint() -> void:
	var made := WorldTestKit.village(3)
	var world := GroundWorld.of(made)
	var taken := 0
	for row in world.thing_count():
		var kind := world.thing_kind(row)
		var id := world.thing_ids[row]
		var want := GridLayout.footprint(world.thing_cell(row), kind.width, kind.depth)
		check_eq(made.grid.thing_cells(id), want)
		for cell in want:
			check_eq(made.grid.occupant(cell), id)
		taken += want.size()
	var occupied := 0
	for cell in WorldTestKit.cells_of(made):
		if made.grid.occupant(cell) != VillageGrid.NOTHING:
			occupied += 1
	check_eq(occupied, taken, "only the things of the world take cells")


func test_a_small_world_keeps_the_shares_of_the_jam_map() -> void:
	var world := GroundWorld.of(WorldTestKit.village(4, 2091))
	var recipe := world.recipe
	check_eq(recipe.amount_for(&"tree", 2091), 60)
	check_eq(recipe.amount_for(&"big_rock", 2091), 36)
	for kind_name: StringName in world.wanted:
		check_eq(world.wanted[kind_name], recipe.amount_for(kind_name, world.cells))
		check(absi(world.wanted[kind_name] - recipe.amounts[kind_name]) <= 1, "%s" % kind_name)


func test_a_band_that_is_full_ends_the_placing() -> void:
	var recipe := WorldTestKit.recipe()
	recipe.amounts = {&"big_tree": 5000, &"big_rock": 5000} as Dictionary[StringName, int]
	var made := WorldTestKit.village(5, 500, recipe)
	var world := GroundWorld.of(made)
	var dark := WorldTestKit.count_ground(made, WorldTestKit.DARK)
	var placed := world.placed[&"big_tree"] + world.placed[&"big_rock"]
	check(placed < world.wanted[&"big_tree"], "fewer fit than were wanted")
	check(placed * 2 <= dark, "two cells each, all inside the dark band")
	check(placed * 2 >= dark / 2, "and the band is well used: %d things" % placed)
	check_eq(world.thing_count(), placed)


func test_a_kind_in_two_bands_is_split_by_their_size() -> void:
	var recipe := WorldTestKit.recipe()
	recipe.bands[0].kinds = [&"tree"] as Array[StringName]
	recipe.bands[1].kinds = [&"tree"] as Array[StringName]
	recipe.amounts = {&"tree": 400} as Dictionary[StringName, int]
	var made := WorldTestKit.village(5, WorldTestKit.CELLS, recipe)
	var world := GroundWorld.of(made)
	var wanted := world.wanted[&"tree"]
	check_eq(world.placed[&"tree"], wanted)
	var in_dark := 0
	for row in world.thing_count():
		if made.grid.ground(world.thing_cell(row)) == WorldTestKit.DARK:
			in_dark += 1
	check(absi(in_dark - roundi(wanted * 0.25)) <= 1, "a quarter stands in the dark: %d" % in_dark)
