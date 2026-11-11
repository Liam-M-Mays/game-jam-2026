extends GameTest
## Checks that the mouse finds the right thing with maths: by the picture in
## front, and by the cell where no picture is hit. Hover and click both use
## [method BatchRows.pick], so one test covers both.

const ROCK := 1
const TOWER := 2
const WIDE_LEFT := 3
const WIDE_RIGHT := 4
const HOUSE := 5

var _rows: BatchRows
var _cells := BatchCells.new()


## The scene, in pixels:
## - A rock, 40 by 40, stands on cell (6, 3). It covers x 550 to 590 and y 120 to 160.
## - A tower, 60 by 300, stands on cell (5, 5), two rows in front of the rock.
##   It covers x 560 to 620 and y -40 to 260. Its left 20 pixels are see-through,
##   so it is solid from x 580.
## - Two wide sprites, 100 by 40, stand side by side on cells (20, 3) and (21, 3).
func before_each() -> void:
	var atlas := BatchTestKit.atlas()
	var small := atlas.find(BatchTestKit.SMALL)
	var tall := atlas.find(BatchTestKit.TALL)
	var wide := atlas.find(BatchTestKit.WIDE)
	_rows = BatchRows.new(_cells, atlas, Rect2(0.0, 0.0, 3000.0, 1000.0))
	_rows.add_thing(ROCK, Vector2i(6, 3), small, BatchTestKit.SMALL_OFFSET)
	_rows.add_thing(TOWER, Vector2i(5, 5), tall, BatchTestKit.TALL_OFFSET)
	_rows.add_thing(WIDE_LEFT, Vector2i(20, 3), wide, BatchTestKit.SMALL_OFFSET)
	_rows.add_thing(WIDE_RIGHT, Vector2i(21, 3), wide, BatchTestKit.SMALL_OFFSET)
	var footprint: Array[Vector2i] = [Vector2i(30, 8), Vector2i(31, 8), Vector2i(30, 9)]
	_rows.add_thing(HOUSE, Vector2i(30, 8), small, BatchTestKit.SMALL_OFFSET, Color.WHITE, footprint)


func test_a_point_on_a_thing_finds_it() -> void:
	check_eq(_rows.pick(Vector2(555.0, 140.0)), ROCK)
	check_eq(_rows.pick(Vector2(600.0, 200.0)), TOWER)


func test_a_tall_sprite_is_found_where_it_sticks_up_over_the_rows_behind() -> void:
	# Far above the tower's own cell, over rows 1 and 0.
	check_eq(_cells.cell_at(Vector2(600.0, 40.0)).y, 1)
	check_eq(_rows.pick(Vector2(600.0, 40.0)), TOWER)
	check_eq(_rows.pick(Vector2(610.0, -30.0)), TOWER)
	# Over the rock's own cell and the rock's own picture: the tower is in front.
	check_eq(_cells.cell_at(Vector2(585.0, 140.0)), Vector2i(6, 3))
	check_eq(_rows.pick(Vector2(585.0, 140.0)), TOWER)


func test_a_see_through_part_of_a_tall_sprite_does_not_count() -> void:
	# Inside the tower's frame, but on its see-through strip. The rock shows there.
	check_eq(_rows.pick(Vector2(570.0, 140.0)), ROCK)
	# The same strip over a cell where nothing stands.
	check_eq(_rows.thing_on_cell(_cells.cell_at(Vector2(565.0, 40.0))), BatchRows.NO_THING)
	check_eq(_rows.pick(Vector2(565.0, 40.0)), BatchRows.NO_THING)


func test_a_point_on_a_cell_finds_what_stands_on_it() -> void:
	# On the rock's cell, next to the rock's picture.
	var beside := Vector2(540.0, 170.0)
	check_eq(_rows.pick_sprite(beside), BatchRows.NO_THING)
	check_eq(_cells.cell_at(beside), Vector2i(6, 3))
	check_eq(_rows.pick(beside), ROCK)
	# Every cell of a thing that takes more than one cell.
	for cell: Vector2i in [Vector2i(30, 8), Vector2i(31, 8), Vector2i(30, 9)]:
		check_eq(_rows.pick(_cells.position_of(cell) + Vector2(20.0, 20.0)), HOUSE)


func test_a_point_on_empty_ground_finds_nothing() -> void:
	check_eq(_rows.pick(Vector2(1000.0, 600.0)), BatchRows.NO_THING)
	check_eq(_rows.pick(Vector2(-5000.0, -5000.0)), BatchRows.NO_THING)
	check_eq(_rows.pick(Vector2(90000.0, 90000.0)), BatchRows.NO_THING)


func test_where_two_pictures_overlap_only_the_front_one_is_found() -> void:
	# The two wide sprites are 70 pixels apart and 100 wide, so they overlap.
	var left := _cells.position_of(Vector2i(20, 3))
	var overlap := left + Vector2(35.0, -10.0)
	# In one row the left thing is drawn in front.
	check_eq(_rows.pick(overlap), WIDE_LEFT)
	check_eq(_rows.pick(left + Vector2(-40.0, -10.0)), WIDE_LEFT)
	check_eq(_rows.pick(left + Vector2(110.0, -10.0)), WIDE_RIGHT)


func test_a_thing_that_was_taken_away_is_not_found() -> void:
	_rows.remove_thing(TOWER)
	check_eq(_rows.pick(Vector2(600.0, 40.0)), BatchRows.NO_THING)
	check_eq(_rows.pick(Vector2(585.0, 140.0)), ROCK)
	_rows.remove_thing(ROCK)
	check_eq(_rows.pick(Vector2(585.0, 140.0)), BatchRows.NO_THING)
	check_eq(_rows.pick(Vector2(540.0, 170.0)), BatchRows.NO_THING)


func test_the_cell_maths_can_be_swapped() -> void:
	# The same scene on a grid that starts somewhere else: every pick moves with it.
	var moved := BatchCells.new()
	moved.origin = Vector2(4000.0, 3000.0)
	var atlas := BatchTestKit.atlas()
	var rows := BatchRows.new(moved, atlas, Rect2(4000.0, 3000.0, 3000.0, 1000.0))
	rows.add_thing(ROCK, Vector2i(6, 3), atlas.find(BatchTestKit.SMALL), BatchTestKit.SMALL_OFFSET)
	rows.add_thing(TOWER, Vector2i(5, 5), atlas.find(BatchTestKit.TALL), BatchTestKit.TALL_OFFSET)
	check_eq(rows.pick(moved.origin + Vector2(555.0, 140.0)), ROCK)
	check_eq(rows.pick(moved.origin + Vector2(600.0, 40.0)), TOWER)
	check_eq(rows.pick(moved.origin + Vector2(540.0, 170.0)), ROCK)
	check_eq(rows.pick(Vector2(555.0, 140.0)), BatchRows.NO_THING)
