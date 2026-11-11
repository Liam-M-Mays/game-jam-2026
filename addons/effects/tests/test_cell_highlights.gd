extends GameTest
## Checks the cell highlights: which cells are lit, in which colour, and
## which cells a circle round the mouse touches.

const GREY := Color(0.4, 0.4, 0.4, 0.5)
const YELLOW := Color(1.0, 0.95, 0.6, 0.7)
const DARK := Color(0.0, 0.0, 0.0, 0.0)

var _rows: BatchRows
var _cells: CellHighlights
var _small: int


func before_each() -> void:
	_rows = EffectsTestKit.rows()
	_small = _rows.atlas.find(BatchTestKit.SMALL)
	_cells = CellHighlights.new(_rows, _small, Vector2(-0.5, 0.0))


func test_a_cell_is_dark_until_something_lights_it() -> void:
	check_eq(_cells.lit_count(), 0)
	check_eq(_rows.decor_count(), 0)
	check_eq(_cells.colour_of(Vector2i(2, 3)), DARK)


func test_a_lit_cell_is_the_cell_picture_in_the_colour_under_everything() -> void:
	_rows.add_thing(1, Vector2i(2, 2), _small)
	_cells.show(&"hover", [Vector2i(2, 3)], GREY)
	check_eq(_cells.colour_of(Vector2i(2, 3)), GREY)
	var buffer := PackedFloat32Array()
	check_eq(_rows.assemble(BatchTestKit.everything(), buffer), 2)
	var first := BatchTestKit.read(buffer)[0]
	check_eq(first["middle"], Vector2(285.0, 150.0), "half an art pixel left of the cell")
	check_eq(first["tint"], GREY)
	check_eq(first["sprite"], _small)


func test_showing_a_layer_again_replaces_what_it_showed() -> void:
	_cells.show(&"cursor", [Vector2i(1, 1), Vector2i(2, 1)], GREY)
	_cells.show(&"cursor", [Vector2i(2, 1), Vector2i(3, 1)], GREY)
	check_eq(_cells.colour_of(Vector2i(1, 1)), DARK)
	check_eq(_cells.colour_of(Vector2i(2, 1)), GREY)
	check_eq(_cells.colour_of(Vector2i(3, 1)), GREY)
	check_eq(_cells.lit_count(), 2)
	check_eq(_rows.decor_count(), 2)


func test_the_layer_with_the_higher_rank_wins_a_cell() -> void:
	_cells.show(&"area", [Vector2i(1, 1), Vector2i(2, 1)], YELLOW, 2)
	_cells.show(&"hover", [Vector2i(2, 1), Vector2i(3, 1)], GREY, 0)
	_cells.show(&"under_preview", [Vector2i(2, 1)], Color.WHITE, 3)
	check_eq(_cells.colour_of(Vector2i(1, 1)), YELLOW)
	check_eq(_cells.colour_of(Vector2i(2, 1)), Color.WHITE)
	check_eq(_cells.colour_of(Vector2i(3, 1)), GREY)
	check_eq(_rows.decor_count(), 3, "one picture per lit cell, however many layers light it")
	_cells.clear(&"under_preview")
	check_eq(_cells.colour_of(Vector2i(2, 1)), YELLOW, "the next rank down shows again")
	_cells.clear(&"area")
	check_eq(_cells.colour_of(Vector2i(2, 1)), GREY)
	check_eq(_cells.colour_of(Vector2i(1, 1)), DARK)


func test_a_lit_cell_that_changes_colour_is_drawn_in_the_new_colour() -> void:
	# The barn plot: the plot cells are pale yellow, the cell under the
	# preview turns white, and yellow again when the preview moves on.
	var under := Vector2i(2, 1)
	_cells.show(&"area", [Vector2i(1, 1), under], YELLOW, 2)
	check_eq(_drawn_tint(under), YELLOW)
	_cells.show(&"under_preview", [under], Color.WHITE, 3)
	check_eq(_drawn_tint(under), Color.WHITE, "what the batch draws is white now")
	check_eq(_drawn_tint(Vector2i(1, 1)), YELLOW, "its neighbour is not")
	_cells.clear(&"under_preview")
	check_eq(_drawn_tint(under), YELLOW, "and yellow again")
	check_eq(_rows.decor_count(), 2)


func test_clearing_makes_the_cells_dark_again() -> void:
	_cells.show(&"hover", [Vector2i(1, 1)], GREY)
	_cells.show(&"area", [Vector2i(5, 5), Vector2i(6, 5)], YELLOW)
	_cells.clear(&"hover")
	check_eq(_cells.lit_count(), 2)
	_cells.clear(&"not a layer")
	check_eq(_cells.lit_count(), 2)
	_cells.clear_all()
	check_eq(_cells.lit_count(), 0)
	check_eq(_rows.decor_count(), 0)


func test_a_circle_of_no_size_touches_only_the_cell_it_is_in() -> void:
	var at := BatchTestKit.cells().position_of(Vector2i(2, 3))
	check_eq(_touched(at, 0.0), [Vector2i(2, 3)] as Array[Vector2i])
	check_eq(_touched(at, 15.0), [Vector2i(2, 3)] as Array[Vector2i])


func test_a_bigger_circle_touches_the_cells_whose_outline_it_reaches() -> void:
	# On the test grid the outline of a cell is a box of 40 by 40. From the
	# middle of cell (2, 3) the nearest corner of (3, 2) and of (1, 4) is 30
	# away, and the nearest corner of (2, 2) and of (2, 4) is 42.4 away.
	var at := BatchTestKit.cells().position_of(Vector2i(2, 3))
	var want: Array[Vector2i] = [Vector2i(3, 2), Vector2i(2, 3), Vector2i(1, 4)]
	check_eq(_touched(at, 35.0), want)
	check_eq(_touched(at, 29.0), [Vector2i(2, 3)] as Array[Vector2i])
	check_eq(_touched(at, 43.0).size(), 5)


func test_a_circle_between_cells_touches_none() -> void:
	var at := BatchTestKit.cells().position_of(Vector2i(2, 3)) + Vector2(35.0, 0.0)
	check_eq(_touched(at, 10.0), [] as Array[Vector2i])
	check_eq(_touched(at, 15.0), [Vector2i(2, 3), Vector2i(3, 3)] as Array[Vector2i])


func _touched(centre: Vector2, radius: float) -> Array[Vector2i]:
	var box := PackedVector2Array([
		Vector2(-20.0, -20.0), Vector2(20.0, -20.0), Vector2(20.0, 20.0), Vector2(-20.0, 20.0),
	])
	return CellHighlights.cells_in_circle(BatchTestKit.cells(), box, centre, radius)


## The colour of the cell picture the batch draws on [param cell]. It is read
## from the assembled sprites, not from the books of the highlights.
func _drawn_tint(cell: Vector2i) -> Color:
	var middle := _rows.cells.position_of(cell) + Vector2(-0.5, 0.0) * _rows.pixel_scale
	var buffer := PackedFloat32Array()
	_rows.assemble(BatchTestKit.everything(), buffer)
	for sprite in BatchTestKit.read(buffer):
		if sprite["middle"] == middle:
			return sprite["tint"]
	return DARK
