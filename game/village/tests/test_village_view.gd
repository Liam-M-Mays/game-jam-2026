extends GameTest
## Checks the picture of a village: it joins the village grid to the sprite
## batch, it shows every thing of the world, and it never changes the village.

const TICKS := 1000
const FRAME_EVERY := 25

var _views: Array[VillageView] = []


## A stand-in for the parts that come later. It wakes every third tick and,
## with the village's own random numbers, stands a thing on a free cell (two
## times in four), takes one away, or drops something on a cell.
class Busy:
	extends VillagePart
	var things: Array[int] = []
	var wakes: int = 0

	## Goes to sleep for the first time.
	func start(village: Village) -> void:
		village.timers.wake_after(3, _wake)

	## The things it placed and how often it woke.
	func snapshot() -> Dictionary:
		return {"things": things.duplicate(), "wakes": wakes}

	func _wake(village: Village) -> void:
		wakes += 1
		var rng := village.rng
		var world := GroundWorld.of(village)
		var cell := world.start_cell + Vector2i(rng.randi_range(-9, 9), rng.randi_range(-9, 9))
		match rng.randi_range(0, 3):
			0, 1:
				var thing := village.new_id()
				if village.grid.place(thing, cell):
					things.append(thing)
			2:
				if not things.is_empty():
					village.grid.remove(things.pop_at(rng.randi_range(0, things.size() - 1)))
			3:
				village.grid.drops.add(cell, 1, rng.randi_range(1, 3))
		village.timers.wake_after(3, _wake)


## A picture layer that breaks the rule: it takes a random number from the
## village in every frame.
class Meddler:
	extends VillageViewLayer

	## Takes a random number from the village, which a picture must never do.
	func update(village: Village, _view: VillageView) -> void:
		village.rng.randi()


func after_each() -> void:
	for view in _views:
		view.free()
	_views.clear()


func test_a_village_runs_the_same_with_and_without_its_picture() -> void:
	var shown := _busy_village(21)
	var alone := _busy_village(21)
	var at_start := shown.snapshot()
	var view := _show(shown, VillageLayers.of(shown))
	await _run(shown, alone)
	check_eq(shown.now, TICKS)
	check_eq(alone.now, TICKS)
	check(shown.snapshot() == alone.snapshot(), "the same state after 1,000 ticks")
	check_eq(shown.state_hash(), alone.state_hash())
	check(shown.snapshot() != at_start, "and the village did change in those ticks")
	var busy := shown.part(&"busy") as Busy
	check_eq(busy.wakes, 333, "the stand-in part woke every third tick")
	check(busy.things.size() > 0, "and things stand that were not there: %d" % busy.things.size())
	check_eq(view.layer_count(), 2, "the picture had its layers")
	check_eq(view.rows.thing_count(), GroundWorld.of(shown).thing_count())


func test_the_comparison_sees_a_picture_that_touches_the_village() -> void:
	var shown := _busy_village(21)
	var alone := _busy_village(21)
	var layers := VillageLayers.of(shown)
	layers.append(Meddler.new())
	_show(shown, layers)
	await _run(shown, alone)
	check(shown.snapshot() != alone.snapshot(), "a picture that takes a random number is seen")


func test_putting_the_picture_on_changes_nothing_in_the_village() -> void:
	var made := WorldTestKit.village(22)
	var before := made.snapshot()
	var view := _show(made, VillageLayers.of(made))
	await tree.process_frame
	check(made.snapshot() == before, "the village is as it was")
	view.detach()
	check(made.snapshot() == before, "also after the picture is taken off")
	check(view.village == null and view.rows == null and view.batch == null, "it let go")
	check(not made.is_closed(), "the village is still open")


func test_the_batch_cells_are_the_cells_of_the_village_grid() -> void:
	var cells := VillageView.batch_cells()
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(3, 4), Vector2i(-60, 25), Vector2i(140, -200)]:
		var want := GridLayout.position_of(cell) * VillageView.ART_SCALE
		check_eq(cells.position_of(cell), want, "cell %s" % cell)
	var dice := RandomNumberGenerator.new()
	dice.seed = 5
	for index in 400:
		var art := Vector2(dice.randf_range(-900.0, 900.0), dice.randf_range(-900.0, 900.0))
		var got := cells.cell_at(VillageView.to_pixels(art))
		check_eq(got, GridLayout.cell_under(art), "the cell under art point %s" % art)
	check_eq(VillageView.to_art(VillageView.to_pixels(Vector2(3.5, -2.0))), Vector2(3.5, -2.0))
	check_eq(VillageView.to_pixels(Vector2(1.0, 1.0)), Vector2(10.0, 10.0))


func test_every_thing_of_the_world_is_in_the_batch() -> void:
	var made := WorldTestKit.village(23)
	var world := GroundWorld.of(made)
	var view := _show(made, VillageLayers.of(made))
	check_eq(view.rows.thing_count(), world.thing_count())
	check(world.thing_count() > 150, "the world has things")
	for row in world.thing_count():
		var id := world.thing_ids[row]
		check(view.rows.has_thing(id), "thing %d is in the batch" % id)
		for cell in made.grid.thing_cells(id):
			check_eq(view.rows.thing_on_cell(cell), id, "the batch finds it on cell %s" % cell)


func test_a_thing_is_drawn_with_the_sprite_and_offset_of_its_kind() -> void:
	var sizes: Array[Vector2i] = []
	for kind in NatureKinds.all():
		var recipe := WorldTestKit.recipe()
		recipe.amounts = {kind.kind_name: 1} as Dictionary[StringName, int]
		var made := WorldTestKit.village(24, 2091, recipe)
		var world := GroundWorld.of(made)
		check_eq(world.thing_count(), 1, "one %s stands" % kind.kind_name)
		check_eq(world.thing_kind(0), kind)
		var view := _show(made, VillageLayers.of(made))
		var wrong := _wrong_pixels(view, world, kind)
		check_eq(wrong, 0, "%s: art pixels where the batch shows another picture" % kind.kind_name)
		check(not sizes.has(kind.region.size), "%s has a size of its own" % kind.kind_name)
		sizes.append(kind.region.size)
	check_eq(sizes.size(), 5, "all five kinds were looked at")


func test_the_layers_of_a_village_are_listed_in_one_place() -> void:
	var with_world := VillageLayers.of(WorldTestKit.village(25, 500))
	check_eq(with_world.size(), 2)
	check(with_world[0] is GroundLayer, "the ground comes first")
	check(with_world[1] is WorldThingsLayer, "then the things of the world")
	check_eq(VillageLayers.of(Village.new(25, 20)).size(), 0, "a village with no world has none")


func test_a_picture_shows_one_village_and_the_ground_is_behind() -> void:
	var made := WorldTestKit.village(26, 500)
	var view := _show(made, VillageLayers.of(made))
	var bounds := GroundWorld.of(made).bounds
	check(not view.attach(WorldTestKit.village(27, 500), bounds, []), "a second village is refused")
	check_eq(view.village, made)
	var ground := view.get_node("Ground")
	check(ground.get_index() < view.batch.get_index(), "the ground is drawn before the batch")
	check_eq(view.batch.rows, view.rows)
	check_eq(view.batch.material().shader, SpriteBatch.PLAIN_SHADER, "no layer asked for a shader")


## Compares the one thing of [param world] in the batch with the picture of
## [param kind], art pixel by art pixel, with one pixel of air all round.
## The batch must find the thing exactly on the solid pixels of that picture,
## at the offset of the kind. Returns how many art pixels are wrong.
func _wrong_pixels(view: VillageView, world: GroundWorld, kind: NatureKind) -> int:
	var sheet := kind.sheet.get_image()
	var size := kind.region.size
	var corner := GridLayout.position_of(world.thing_cell(0)) + kind.offset - Vector2(size) * 0.5
	var wrong := 0
	for y in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			var solid := false
			if x >= 0 and y >= 0 and x < size.x and y < size.y:
				solid = sheet.get_pixelv(kind.region.position + Vector2i(x, y)).a > SpriteAtlas.SOLID_ALPHA
			var want := world.thing_ids[0] if solid else BatchRows.NO_THING
			var point := VillageView.to_pixels(corner + Vector2(x + 0.5, y + 0.5))
			if view.rows.pick_sprite(point) != want:
				wrong += 1
	return wrong


## A village with a small world and the stand-in part.
func _busy_village(world_seed: int) -> Village:
	var made := WorldTestKit.village(world_seed)
	made.add_part(&"busy", Busy.new())
	return made


## Puts a picture of [param made] into the scene.
func _show(made: Village, layers: Array[VillageViewLayer]) -> VillageView:
	var view := VillageView.new()
	tree.current_scene.add_child(view)
	view.attach(made, GroundWorld.of(made).bounds, layers)
	_views.append(view)
	return view


## Ticks both villages 1,000 times. A frame passes every 25 ticks, so the
## picture of the shown one is drawn 40 times on the way.
func _run(shown: Village, alone: Village) -> void:
	for tick in TICKS:
		shown.tick()
		alone.tick()
		if tick % FRAME_EVERY == 0:
			await tree.process_frame
