class_name MeepleTestKit
extends RefCounted
## Helpers the meeple tests share: a small village with a flat grid and the
## meeples part, and short ways to send the two meeple commands.

## The tick rate of the test villages. One tick is a twentieth of a second.
const TICKS_PER_SECOND := 20
## The grid of a test village: a block of this many cells, from cell (0, 0).
const MAP := Vector2i(60, 40)


## Returns a village made from [param village_seed] with a flat grid and an
## empty meeples part. [param tick_rate] is its ticks per second.
static func village(village_seed: int = 1, tick_rate: int = TICKS_PER_SECOND) -> Village:
	var made := Village.new(village_seed, tick_rate)
	for cell in GridLayout.block(Vector2i.ZERO, MAP):
		made.grid.add_cell(cell)
	made.add_part(Village.MEEPLES, VillageMeeples.new())
	return made


## Returns the meeples part of [param of_village].
static func meeples(of_village: Village) -> VillageMeeples:
	return of_village.part(Village.MEEPLES) as VillageMeeples


## Runs [param ticks] ticks on [param on_village].
static func run(on_village: Village, ticks: int) -> void:
	for tick in ticks:
		on_village.tick()


## Adds a meeple at [param spot] with the spawn command and returns its id.
static func spawn(in_village: Village, spot: Vector2) -> int:
	var command := MeepleCommands.Spawn.new(spot)
	in_village.send(command)
	return command.meeple


## Kills [param meeple] with the kill command. Returns false when it was refused.
static func kill(in_village: Village, meeple: int) -> bool:
	return in_village.send(MeepleCommands.Kill.new(meeple))


## Sends [param meeple] on a job walk that ends on [param target]. A job
## walk ends a little below the point it is given, so this hands in the point
## above the target.
static func send(in_village: Village, meeple: int, target: Vector2, stop_thing: int = 0) -> void:
	var point := target - MeepleNumbers.AIM_BELOW
	meeples(in_village).walk_to(in_village, meeple, point, stop_thing)


## Gives [param meeple] a job on the spot where it stands, so it stays there
## and does not wander off.
static func hold(in_village: Village, meeple: int) -> void:
	var part := meeples(in_village)
	send(in_village, meeple, part.spots[part.row_of(meeple)])


## Returns the middle of the test grid, in art pixels. A meeple there is far
## from every edge.
static func middle() -> Vector2:
	@warning_ignore("integer_division")
	return GridLayout.position_of(Vector2i(MAP.x / 2, MAP.y / 2))


## Stands a thing of [param width] by [param depth] cells on [param anchor]
## and returns its id.
static func place_thing(
	in_village: Village, anchor: Vector2i, width: int = 1, depth: int = 1
) -> int:
	var thing := in_village.new_id()
	in_village.grid.place(thing, anchor, width, depth)
	return thing


## A sprite batch with the meeple look and a [MeepleView] on a village, for
## the tests of the picture. It needs no window. Call [method close] at the end.
class Stage:
	extends RefCounted
	## How many pixels one art pixel takes in the batch of the tests.
	const ART_SCALE := 10.0
	## Where cell (0, 0) is in the batch of the tests. It is not at zero, so a
	## test notices a view that forgets it.
	const ORIGIN := Vector2(300.0, 200.0)
	## The load kinds of the tests.
	const LOAD_NAMES: Dictionary[int, StringName] = {1: &"wood", 2: &"stone"}

	var look := MeepleLook.new()
	var rows: BatchRows
	var batch: SpriteBatch
	var view: MeepleView

	## Builds the batch and the view for [param village] and adds both to [param holder].
	func _init(village: Village, holder: Node) -> void:
		var atlas := SpriteAtlas.new()
		look.add_to(atlas)
		atlas.build()
		var cells := BatchCells.new(
			GridLayout.CELL_WIDTH * ART_SCALE,
			GridLayout.ROW_SHIFT * ART_SCALE,
			GridLayout.ROW_HEIGHT * ART_SCALE,
			GridLayout.CELL_MIDDLE * ART_SCALE,
			ORIGIN
		)
		rows = BatchRows.new(cells, atlas, Rect2(-1000.0, -1000.0, 12000.0, 6000.0), ART_SCALE)
		look.shape(rows)
		batch = SpriteBatch.new()
		batch.setup(rows, MeepleLook.SHADER)
		look.dress(batch)
		batch.clock_frozen = true
		holder.add_child(batch)
		view = MeepleView.new()
		view.load_names = LOAD_NAMES
		view.setup(MeepleTestKit.meeples(village), batch, look)
		holder.add_child(view)
		# The tests call show_frame themselves, with the fraction they want.
		# A node starts to process when it is added, so it is stopped after that.
		view.set_process(false)

	## Where a spot of the village is in the batch, in pixels.
	func in_batch(spot: Vector2) -> Vector2:
		return ORIGIN + spot * ART_SCALE

	## What the batch draws for the meeple in [param row]: "middle", "tint"
	## and "numbers", as [method BatchTestKit.read] gives them. It is found by
	## its place, so give the meeples of a test different spots.
	func mover(row: int) -> Dictionary:
		var buffer := PackedFloat32Array()
		rows.assemble(BatchTestKit.everything(), buffer)
		var middle := view.shown_spot(row) + MeepleLook.BOX_OFFSET * ART_SCALE
		for sprite in BatchTestKit.read(buffer):
			if middle.distance_to(sprite["middle"]) < 0.01:
				return sprite
		return {}

	## Frees the two nodes.
	func close() -> void:
		view.free()
		batch.free()
