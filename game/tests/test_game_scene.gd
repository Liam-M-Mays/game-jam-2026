extends GameTest
## Checks the new game scene: it starts one village on a generated world and
## shows it, it takes its seed and its size from the dev settings, it prints
## the seed, and it ends the session when it goes.
##
## Every test hands the scene its own dev settings with a small world. So no
## test builds the world of 100,000 cells, and only the test of the random
## seed runs on a seed it does not choose.

const SCENE := "res://game/game.tscn"
## The world size these tests ask for. The real one is 100,000.
const CELLS := 2000


## Hears every line the engine prints while it is switched on.
class Listener:
	extends Logger
	var lines: PackedStringArray = []

	func _log_message(message: String, _error: bool) -> void:
		lines.append(message.strip_edges())


func test_the_game_scene_starts_one_village_on_a_generated_world() -> void:
	var scene := await _start(1234)
	check_eq(Game.village_count(), 1)
	var village: Village = scene.get("village")
	check_eq(Game.village_in_view, village, "the village is the one in view")
	var world := GroundWorld.of(village)
	check(world != null, "the village has a ground world")
	check_eq(world.asked_cells, CELLS, "of the size in the dev settings")
	check(absi(world.cells - CELLS) <= CELLS / 50, "which it has, near enough: %d" % world.cells)
	check_eq(village.grid.cell_count(), world.cells)
	var view: VillageView = scene.get("view")
	check_eq(view.village, village)
	check_eq(view.rows.thing_count(), world.thing_count(), "every thing is in the batch")
	var camera := tree.root.get_camera_2d()
	var start := VillageView.to_pixels(GridLayout.position_of(world.start_cell))
	check_eq(camera.position, start, "the camera looks at the start cell")
	check(Game.villages().has(village), "the session holds the village, so it ticks")
	scene.free()
	check_eq(Game.village_count(), 0, "leaving the scene ends the session")
	check(village.is_closed(), "and closes the village")


func test_a_fixed_seed_in_the_dev_settings_is_the_seed_of_the_world() -> void:
	var listener := Listener.new()
	OS.add_logger(listener)
	var scene := await _start(1234)
	OS.remove_logger(listener)
	var village: Village = scene.get("village")
	check_eq(village.village_seed, 1234, "the village has the fixed seed")
	check(listener.lines.has("World seed: 1234"), "the seed was printed: %s" % [listener.lines])
	var same := Village.new(1234, 20)
	WorldGenerator.generate(same, CELLS)
	check(
		GroundWorld.of(village).snapshot() == GroundWorld.of(same).snapshot(),
		"and the world is the world of that seed"
	)
	scene.free()


func test_no_fixed_seed_gives_the_game_a_random_seed() -> void:
	var listener := Listener.new()
	OS.add_logger(listener)
	var first := await _start(WorldSeed.RANDOM)
	var first_seed: int = (first.get("village") as Village).village_seed
	first.free()
	var second := await _start(WorldSeed.RANDOM)
	var second_seed: int = (second.get("village") as Village).village_seed
	second.free()
	OS.remove_logger(listener)
	for world_seed: int in [first_seed, second_seed]:
		check(world_seed >= 1 and world_seed <= WorldSeed.HIGHEST, "in range: %d" % world_seed)
		check(listener.lines.has(WorldSeed.line(world_seed)), "seed %d was printed" % world_seed)
	check(first_seed != second_seed, "two games got two seeds")


## Starts the game scene on a small world. [param world_seed] is the fixed
## seed of its dev settings, where 0 means a random one.
func _start(world_seed: int) -> Node:
	var settings := DevSettings.new()
	settings.world_seed = world_seed
	settings.world_cells = CELLS
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	scene.set("settings", settings)
	tree.current_scene.add_child(scene)
	await tree.process_frame
	return scene
