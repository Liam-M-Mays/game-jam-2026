extends GameTest
## Checks the new game scene: it starts one village on a generated world and
## shows it, and it ends the session when it goes.

const SCENE := "res://game/game.tscn"


func test_the_game_scene_starts_one_village_on_a_generated_world() -> void:
	var asked := DevSettings.load_settings().world_cells
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	tree.current_scene.add_child(scene)
	await tree.process_frame
	check_eq(Game.village_count(), 1)
	var village: Village = scene.get("village")
	check_eq(Game.village_in_view, village, "the village is the one in view")
	var world := GroundWorld.of(village)
	check(world != null, "the village has a ground world")
	check(absi(world.cells - asked) <= asked / 50, "of the size in the dev settings: %d" % world.cells)
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
