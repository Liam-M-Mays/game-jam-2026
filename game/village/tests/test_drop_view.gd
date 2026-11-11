extends GameTest
## Checks that the drop view puts one sprite into the batch for each drop, on
## the spot where the drop lies, and takes it out again.

const WOOD := 1
const STONE := 2
## How many screen pixels one art pixel takes at zoom 1, as in the jam game.
const ART_SCALE := 10.0
const WORLD := Rect2(-200.0, -200.0, 3000.0, 2000.0)
const TREE := 5

var _grid: VillageGrid
var _rows: BatchRows
var _view: DropView
var _sprites: Dictionary[int, int]


## A grid, and a batch that uses the numbers of that grid.
func before_each() -> void:
	_grid = VillageGrid.new()
	for cell in GridLayout.block(Vector2i(0, 0), Vector2i(20, 20)):
		_grid.add_cell(cell)
	var atlas := SpriteAtlas.new()
	_sprites = DropView.add_sprites(atlas, ResourceKind.load_all())
	atlas.build()
	var cells := BatchCells.new(
		GridLayout.CELL_WIDTH * ART_SCALE,
		GridLayout.ROW_SHIFT * ART_SCALE,
		GridLayout.ROW_HEIGHT * ART_SCALE,
		GridLayout.CELL_MIDDLE * ART_SCALE,
		Vector2.ZERO
	)
	_rows = BatchRows.new(cells, atlas, WORLD, ART_SCALE)
	_view = DropView.new(_rows, _sprites)


func test_only_the_item_kinds_get_a_picture() -> void:
	check_eq(_sprites.keys(), [WOOD, STONE])
	check_eq(_rows.atlas.size_of(_sprites[WOOD]), Vector2i(3, 1))
	check_eq(_rows.atlas.size_of(_sprites[STONE]), Vector2i(2, 1))


func test_a_drop_is_drawn_with_its_middle_on_the_spot_where_it_lies() -> void:
	_view.watch(_grid.drops)
	# Not the middle of the cell: 2.3 art pixels left of the cell and 1.2 up.
	var spot := GridLayout.position_of(Vector2i(3, 2)) + Vector2(-2.3, -1.2)
	var drop := _grid.drops.add_at(spot, WOOD)
	check(_rows.has_thing(DropView.thing_of(drop)), "the drop is in the batch")
	var record := _records()
	check_eq(record.size(), BatchRows.FLOATS, "one sprite is drawn")
	check_near(record[3], spot.x * ART_SCALE, 0.001, "the middle, across")
	check_near(record[7], spot.y * ART_SCALE, 0.001, "the middle, down")
	check_near(record[0], 3 * ART_SCALE, 0.001, "wood is 3 art pixels wide, at 10 times")
	check_near(record[5], 1 * ART_SCALE, 0.001, "and 1 art pixel tall")
	check_eq(int(record[12]), _sprites[WOOD])


func test_stone_gets_the_stone_picture() -> void:
	_view.watch(_grid.drops)
	_grid.drops.add_at(Vector2(61.0, 40.0), STONE)
	var record := _records()
	check_near(record[0], 2 * ART_SCALE, 0.001, "stone is 2 art pixels wide, at 10 times")
	check_eq(int(record[12]), _sprites[STONE])
	check_near(record[3], 610.0, 0.001)
	check_near(record[7], 400.0, 0.001)


func test_a_taken_drop_leaves_the_batch_and_a_claimed_one_stays() -> void:
	_view.watch(_grid.drops)
	var first := _grid.drops.add_at(Vector2(31.0, 10.0), WOOD)
	var second := _grid.drops.add_at(Vector2(33.0, 11.0), WOOD)
	check_eq(_rows.thing_count(), 2)
	_grid.drops.claim(second, 31)
	check_eq(_rows.thing_count(), 2, "a claimed drop still lies there")
	_grid.drops.remove(first)
	check_eq(_rows.thing_count(), 1)
	check(not _rows.has_thing(DropView.thing_of(first)), "the taken drop is gone")
	check(_rows.has_thing(DropView.thing_of(second)), "the other one is still drawn")
	var again := _grid.drops.add_at(Vector2(90.0, 60.0), STONE)
	check_eq(again, first, "the row is used again")
	check_eq(_rows.thing_count(), 2)


func test_drops_that_already_lie_there_are_drawn_when_the_view_starts() -> void:
	_grid.drops.add_at(Vector2(31.0, 10.0), WOOD)
	_grid.drops.add_at(Vector2(61.0, 40.0), STONE)
	_grid.drops.remove(_grid.drops.add_at(Vector2(90.0, 60.0), WOOD))
	check_eq(_rows.thing_count(), 0)
	_view.watch(_grid.drops)
	check_eq(_rows.thing_count(), 2)


func test_a_stopped_view_takes_its_drops_out_and_no_longer_listens() -> void:
	_view.watch(_grid.drops)
	_grid.drops.add_at(Vector2(31.0, 10.0), WOOD)
	_rows.add_thing(TREE, Vector2i(5, 5), _sprites[WOOD])
	_view.stop()
	check_eq(_rows.thing_count(), 1, "only the thing that is no drop is left")
	check(_rows.has_thing(TREE), "the tree was not touched")
	_grid.drops.add_at(Vector2(61.0, 40.0), STONE)
	check_eq(_rows.thing_count(), 1)
	check_eq(_grid.drops.added.get_connections().size(), 0)


func test_a_drop_number_never_clashes_with_a_thing_of_the_grid() -> void:
	check_eq(DropView.thing_of(0), -2)
	check_eq(DropView.thing_of(7), -9)
	check_eq(DropView.drop_of(-9), 7)
	check_eq(DropView.drop_of(-2), 0)
	check_eq(DropView.drop_of(BatchRows.NO_THING), GridDrops.NO_DROP)
	check_eq(DropView.drop_of(TREE), GridDrops.NO_DROP, "an id of the village is no drop")
	for drop in 1000:
		if DropView.thing_of(drop) >= BatchRows.NO_THING:
			fail("drop %d got the number of a grid thing" % drop)


## Every sprite the batch would draw for the whole world.
func _records() -> PackedFloat32Array:
	var records := PackedFloat32Array()
	_rows.assemble(WORLD, records)
	return records
