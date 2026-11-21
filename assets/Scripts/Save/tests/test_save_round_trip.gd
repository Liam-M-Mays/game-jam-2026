extends GameTest
## Saving and loading. A village is saved, its level is closed and opened again from the save,
## and the loaded village must hold the same things: trees and rocks with their wear and marks,
## finished and half-built buildings, a building halfway through a move, workers, pile stock, farm growth,
## Town Hall level, meeples, drops and food.

const LEVEL := preload("res://assets/Scenes/Levels/game.tscn")
const SMALL_HUT := preload("res://assets/Scenes/Buildings/small_hut.tscn")
const WOOD_PILE := preload("res://assets/Scenes/Buildings/wood_pile.tscn")
const BARN := preload("res://assets/Scenes/Buildings/barn.tscn")
const FARM := preload("res://assets/Scenes/Buildings/farm.tscn")
const LUMBERJACK := preload("res://assets/Scenes/Buildings/lumberjack.tscn")
const TEST_PATH := "user://test_savegame.dat"

var _level : Node


func before_each() -> void:
	SaveGame.path = TEST_PATH


func after_each() -> void:
	SaveGame.delete_save()
	SaveGame.path = SaveGame.PATH
	SaveGame.set_pending({})
	if is_instance_valid(_level):
		_level.free()
	JobSystem.reset()
	Inventory.reset()


func _open_level() -> Grid:
	_level = LEVEL.instantiate()
	tree.root.add_child(_level)
	return _level.find_child("Grid", true, false) as Grid


func _close_level() -> void:
	_level.free()
	JobSystem.reset()
	Inventory.reset()


## The first free spot, `width` by `depth` cells, with nothing kept on it.
func _free_spot(grid : Grid, width : int, depth := 1) -> Array[Cell]:
	for y in range(grid.grid_size):
		for x in range(grid.grid_size):
			var cells : Array[Cell] = []
			for row in range(depth):
				for i in range(width):
					var cell := grid.cell_at_coords(Vector2i(x + i, y + row))
					if cell != null and cell.occupant == null and cell.kept_for == null:
						cells.append(cell)
			if cells.size() == width * depth:
				return cells
	return []


## A free spot where a whole barn plot area fits too.
func _barn_spot(grid : Grid, barn : Barn) -> Array[Cell]:
	for y in range(grid.grid_size):
		for x in range(grid.grid_size):
			var anchor := grid.cell_at_coords(Vector2i(x, y))
			var next := grid.cell_at_coords(Vector2i(x + 1, y))
			if anchor == null or next == null or anchor.occupant != null or next.occupant != null:
				continue
			var area := barn.area_at(grid, anchor)
			if area.size() == barn.plot_offsets.size() and area.all(func(c : Cell) -> bool: return c.occupant == null and c.kept_for == null):
				return [anchor, next]
	return []


func _place_done(grid : Grid, scene : PackedScene) -> Building:
	var building : Building = scene.instantiate()
	grid.place(building, _free_spot(grid, building.footprint, building.footprint_depth))
	building.complete()
	return building


func _build_village(grid : Grid) -> void:
	TownHall.find_town_hall().upgrade()
	Inventory.add("food", 7)
	var pile := _place_done(grid, WOOD_PILE) as Storage
	pile.restore_stock(3)
	_place_done(grid, LUMBERJACK)
	var hut : Building = SMALL_HUT.instantiate()
	grid.place(hut, _free_spot(grid, hut.footprint, hut.footprint_depth))
	hut.restore_construction(0, {"wood": 1}, true)
	var barn : Barn = BARN.instantiate()
	grid.place(barn, _barn_spot(grid, barn))
	barn.restore_plot_area()
	barn.complete()
	var farm : Farm = FARM.instantiate()
	var plot : Array[Cell] = [barn.plot_area()[0]]
	grid.place(farm, plot)
	farm.join_barn_at(plot)
	farm.complete()
	farm.restore_growth({"growing": true, "growth": 1, "timer": 2.5})
	var items := grid.all_standing()
	items[0].wobbles = 1
	grid.wake(items[1]).mark_for_clearing()
	grid.add_drop(ResourceDrop.scene_of("stone"), grid.cell_at_coords(Vector2i(10, 10)).position if grid.cell_at_coords(Vector2i(10, 10)) else Vector2.ZERO)
	var meeple := grid.spawn_meeple(TownHall.find_town_hall().position)
	meeple.restore_body_color(Color(0.2, 0.4, 0.6))
	var moved := _place_done(grid, LUMBERJACK)
	moved.rebuild_at(grid, _free_spot(grid, moved.footprint, moved.footprint_depth))


## Puts the parts of a save in a fixed order, and leaves out what moves on its own every frame.
func _comparable(data : Dictionary) -> Dictionary:
	var standing : Array = data["standing"].duplicate(true)
	standing.sort_custom(func(a, b) -> bool: return str(a["at"]) < str(b["at"]))
	var meeples : Array = data["meeples"].map(func(m) -> Array: return [m["color"], m["workplace"]])
	meeples.sort_custom(func(a, b) -> bool: return str(a) < str(b))
	var buildings : Array = data["buildings"].duplicate(true)
	buildings.sort_custom(func(a, b) -> bool: return str(a["cells"]) < str(b["cells"]))
	var drops : Array = data["drops"].map(func(d) -> String: return d["kind"])
	drops.sort()
	return {
		"seed": data["seed"],
		"stored": data["stored"],
		"standing": standing,
		"buildings": buildings,
		"meeples": meeples,
		"drops": drops,
	}


func test_a_loaded_village_matches_the_saved_one() -> void:
	await tree.process_frame
	var grid := _open_level()
	_build_village(grid)
	SaveGame.world_opened(grid)
	check(SaveGame.save_now(), "the game saves")
	var before := _comparable(SaveGame.gather(grid))
	_close_level()

	var data := SaveGame.read_save()
	check(not data.is_empty(), "the save file reads back")
	Inventory.restore_stored(data["stored"])
	SaveGame.set_pending(data)
	grid = _open_level()
	check(SaveGame.is_continued(), "the level knows it came from a save")
	var after := _comparable(SaveGame.gather(grid))


	check_eq(after["seed"], before["seed"], "same world seed")
	check_eq(after["stored"], before["stored"], "same food stock")
	check_eq(after["standing"].size(), before["standing"].size(), "same number of trees, rocks and bushes")
	check_eq(after["standing"], before["standing"], "same trees, rocks and bushes, wear and marks")
	check_eq(after["buildings"].size(), before["buildings"].size(), "same number of buildings")
	check_eq(after["buildings"], before["buildings"], "same buildings, stages, stock, growth and level")
	check_eq(after["meeples"], before["meeples"], "same meeples, colours and workplaces")
	check_eq(after["drops"], before["drops"], "same drops on the ground")
	check_eq(TownHall.current_level(), 2, "the Town Hall keeps its level")
	var sites := grid.get_children().filter(func(n : Node) -> bool: return n is Building and (n as Building).moved_from() != null)
	check_eq(sites.size(), 1, "the moved lumberjack's site still takes its drops from the old one")


func test_game_over_deletes_the_save() -> void:
	await tree.process_frame
	var grid := _open_level()
	SaveGame.world_opened(grid)
	SaveGame.save_now()
	check(SaveGame.has_save(), "there is a save")
	Population.all_meeples_died.emit()
	check(not SaveGame.has_save(), "game over deleted it")
	check(not SaveGame.save_now(), "nothing saves after game over")


func test_a_builder_carrying_for_a_move_keeps_its_job() -> void:
	await tree.process_frame
	var grid := _open_level()
	var old := _place_done(grid, LUMBERJACK)
	var site := old.rebuild_at(grid, _free_spot(grid, old.footprint, old.footprint_depth))
	var meeple := grid.spawn_meeple(old.position)
	JobSystem.match_jobs()
	var haul := meeple.job as HaulJob
	check(haul != null and haul.site == site, "a builder took a haul for the moved site")
	haul._pick_up()
	if haul._partner != null:
		haul._partner._pick_up()
	var carried := haul.carried().size()
	SaveGame.world_opened(grid)
	SaveGame.save_now()
	var data := SaveGame.read_save()
	check_eq(data["drops"].size(), 0, "the carried drops are saved with the job, not on the ground")
	_close_level()

	SaveGame.set_pending(data)
	grid = _open_level()
	var carriers := JobSystem.workers.filter(func(m : Meeple) -> bool: return m.job is HaulJob and not m.carried_drops().is_empty())
	check_eq(carriers.size(), 1, "the builder still carries after loading")
	if carriers.size() == 1:
		var loaded := carriers[0].job as HaulJob
		check(loaded.site.moved_from() != null, "it still carries to the moved site, which still takes from its old one")
		check_eq(loaded.carried().size(), carried, "with as many drops as before")
