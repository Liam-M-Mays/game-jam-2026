extends GameTest
## Checks the questions the grid answers for other systems: free cells at a
## point, empty cells within N steps of a thing, and cells at fixed offsets.
## "Which cell is at a point" is in test_village_grid.gd.

const TREE := 11
const ROCK := 12
const HUT := 13

var _grid: VillageGrid


## Lays a block of 10 by 10 cells for every test.
func before_each() -> void:
	_grid = VillageGrid.new()
	for cell in GridLayout.block(Vector2i(0, 0), Vector2i(10, 10)):
		_grid.add_cell(cell)


func test_free_cells_at_a_point_answer_for_the_cell_under_the_point() -> void:
	var point := GridLayout.position_of(Vector2i(6, 6)) + Vector2(1.5, -1.0)
	check_eq(_grid.free_cells_at(point, 2, 2), GridLayout.footprint(Vector2i(6, 6), 2, 2))
	_grid.place(TREE, Vector2i(7, 7))
	check(_grid.free_cells_at(point, 2, 2).is_empty(), "the tree is in the way")
	check_eq(_grid.free_cells_at(point), [Vector2i(6, 6)] as Array[Vector2i])
	check(_grid.free_cells_at(Vector2(-500, -500)).is_empty(), "off the map nothing is free")


func test_empty_cells_within_one_step_of_a_thing_are_its_six_neighbours() -> void:
	_grid.place(TREE, Vector2i(5, 5))
	var want: Array[Vector2i] = [
		Vector2i(4, 5),
		Vector2i(4, 6),
		Vector2i(5, 4),
		Vector2i(5, 6),
		Vector2i(6, 4),
		Vector2i(6, 5),
	]
	check_eq(_grid.empty_cells_near(TREE), want)
	check_eq(_grid.empty_cells_near(TREE, 1), want)


func test_empty_cells_near_a_thing_leave_out_taken_and_missing_cells() -> void:
	_grid.place(TREE, Vector2i(0, 0))
	_grid.place(ROCK, Vector2i(1, 0))
	check_eq(_grid.empty_cells_near(TREE), [Vector2i(0, 1)] as Array[Vector2i])
	check(_grid.empty_cells_near(HUT).is_empty(), "a thing that is not on the grid has none")


func test_empty_cells_within_n_steps_count_from_every_cell_of_the_thing() -> void:
	_grid.place(HUT, Vector2i(4, 4), 2, 2)
	var near := _grid.empty_cells_near(HUT, 2)
	check_eq(near, _jam_cells_around(HUT, 2))
	check_eq(near.size(), 26)
	for cell in near:
		check_eq(_grid.occupant(cell), VillageGrid.NOTHING)
		var nearest := 99
		for own in _grid.thing_cells(HUT):
			nearest = mini(nearest, GridLayout.distance(own, cell))
		check(nearest >= 1 and nearest <= 2, "%s is within 2 steps of the hut" % cell)


func test_empty_cells_near_match_the_jam_game_on_a_busy_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	var id := 100
	for i in 30:
		id += 1
		var anchor := Vector2i(rng.randi_range(0, 9), rng.randi_range(0, 9))
		_grid.place(id, anchor, rng.randi_range(1, 3), rng.randi_range(1, 2))
	var asked := 0
	for thing in range(101, 131):
		if _grid.thing_cells(thing).is_empty():
			continue
		asked += 1
		for steps in range(0, 4):
			check_eq(_grid.empty_cells_near(thing, steps), _jam_cells_around(thing, steps))
	check(asked >= 10, "at least 10 things should have been placed")


func test_cells_at_fixed_offsets_from_a_cell_keep_the_order_and_skip_missing_cells() -> void:
	var offsets: Array[Vector2i] = [
		Vector2i(2, 0),
		Vector2i(0, -1),
		Vector2i(-3, 0),
		Vector2i(0, 2),
		Vector2i(-1, 1),
	]
	var want: Array[Vector2i] = [Vector2i(3, 0), Vector2i(1, 2), Vector2i(0, 1)]
	check_eq(_grid.cells_at_offsets(Vector2i(1, 0), offsets), want)


func test_cells_at_fixed_offsets_also_give_cells_that_are_taken() -> void:
	_grid.place(TREE, Vector2i(3, 0))
	var offsets: Array[Vector2i] = [Vector2i(2, 0)]
	check_eq(_grid.cells_at_offsets(Vector2i(1, 0), offsets), [Vector2i(3, 0)] as Array[Vector2i])


## The "cells around an object" of the jam game, copied from grid.gd lines 61
## to 73, asking the new grid where the old code asked its cells.
func _jam_cells_around(thing: int, radius: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for center in _grid.thing_cells(thing):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var offset := Vector2i(dx, dy)
				@warning_ignore("integer_division")
				var steps := (absi(offset.x) + absi(offset.y) + absi(offset.x + offset.y)) / 2
				if steps > radius:
					continue
				var near := center + offset
				var empty := _grid.has_cell(near) and _grid.occupant(near) == VillageGrid.NOTHING
				if empty and not found.has(near):
					found.append(near)
	return found
