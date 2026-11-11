extends GameTest
## Checks decor: sprites that are only drawn, in one of three layers. The
## effects toolkit uses them for lit cells, sparks and dust clouds.

var _rows: BatchRows
var _atlas: SpriteAtlas
var _small: int
var _tall: int
var _wide: int


func before_each() -> void:
	_atlas = BatchTestKit.atlas()
	_small = _atlas.find(BatchTestKit.SMALL)
	_tall = _atlas.find(BatchTestKit.TALL)
	_wide = _atlas.find(BatchTestKit.WIDE)
	var world := Rect2(-2000.0, -2000.0, 4000.0, 4000.0)
	_rows = BatchRows.new(BatchTestKit.cells(), _atlas, world, BatchTestKit.ART_SCALE)
	_rows.shape_movers(Vector2(30.0, 60.0), Vector2(0.0, -20.0))


func test_the_three_layers_are_drawn_in_their_places() -> void:
	# Row 3 and row 4 each have a thing. A mover walks between the two rows.
	_rows.add_thing(1, Vector2i(2, 3), _small)
	_rows.add_thing(2, Vector2i(2, 4), _small)
	_rows.resize_movers(1)
	_rows.place_mover(0, Vector2(300.0, 170.0), Color.WHITE, Vector4(float(_tall), 0, 0, 1))
	var over := _rows.add_decor(Vector2i(2, 3), _wide, Vector2.ZERO, Color.WHITE, BatchRows.OVER)
	var front := _rows.add_decor(Vector2i(2, 3), _wide, Vector2.ZERO, Color.WHITE, BatchRows.FRONT)
	var under := _rows.add_decor(Vector2i(2, 4), _wide, Vector2.ZERO, Color.WHITE, BatchRows.UNDER)
	check(over != front and front != under and over != under, "each decor has its own number")
	var drawn := _drawn()
	check_eq(drawn.size(), 6)
	check_eq(drawn[0], "wide at (340.0, 200.0)", "under everything, though it is on the lower row")
	check_eq(drawn[1], "small at (290.0, 150.0)", "the thing of row 3")
	check_eq(drawn[2], "wide at (290.0, 150.0)", "in front of the things of its own row")
	check_eq(drawn[3], "tall at (300.0, 150.0)", "the mover below row 3")
	check_eq(drawn[4], "small at (340.0, 200.0)", "the thing of row 4")
	check_eq(drawn[5], "wide at (290.0, 150.0)", "over everything, though it is on the upper row")


func test_front_decor_is_in_front_of_every_thing_of_its_row() -> void:
	# A thing further left is drawn later than one to its right.
	_rows.add_thing(1, Vector2i(1, 3), _small)
	_rows.add_thing(2, Vector2i(5, 3), _small)
	_rows.add_decor(Vector2i(5, 3), _wide)
	var drawn := _drawn()
	check_eq(drawn[2], "wide at (500.0, 150.0)")


func test_a_newer_decor_sprite_is_in_front_of_an_older_one() -> void:
	for layer: int in [BatchRows.UNDER, BatchRows.FRONT, BatchRows.OVER]:
		before_each()
		_rows.add_decor(Vector2i(2, 3), _small, Vector2.ZERO, Color.WHITE, layer)
		_rows.add_decor(Vector2i(2, 3), _wide, Vector2.ZERO, Color.WHITE, layer)
		var drawn := _drawn()
		check_eq(drawn[0], "small at (290.0, 150.0)", "layer %d" % layer)
		check_eq(drawn[1], "wide at (290.0, 150.0)", "layer %d" % layer)


func test_decor_is_placed_like_a_thing_by_cell_and_offset() -> void:
	_rows.add_decor(Vector2i(2, 3), _small, Vector2(1.5, -4.0))
	check_eq(_drawn()[0], "small at (305.0, 110.0)")


func test_decor_is_never_picked_and_stands_on_no_cell() -> void:
	for layer: int in [BatchRows.UNDER, BatchRows.FRONT, BatchRows.OVER]:
		_rows.add_decor(Vector2i(2, 3), _wide, Vector2.ZERO, Color.WHITE, layer)
	var spot := BatchTestKit.cells().position_of(Vector2i(2, 3))
	check_eq(_rows.pick(spot), BatchRows.NO_THING)
	check_eq(_rows.pick_sprite(spot), BatchRows.NO_THING)
	check_eq(_rows.thing_on_cell(Vector2i(2, 3)), BatchRows.NO_THING)
	check_eq(_rows.thing_count(), 0)
	check_eq(_rows.decor_count(), 3)
	_rows.add_thing(7, Vector2i(2, 3), _small)
	check_eq(_rows.pick(spot), 7, "the thing behind the decor is still found")


func test_decor_can_be_tinted_changed_and_taken_away() -> void:
	var first := _rows.add_decor(Vector2i(2, 3), _small, Vector2.ZERO, Color.WHITE, BatchRows.UNDER)
	var second := _rows.add_decor(Vector2i(4, 3), _small, Vector2.ZERO, Color.WHITE, BatchRows.UNDER)
	_rows.tint_decor(first, Color(0.4, 0.4, 0.4, 0.5))
	var sprites := BatchTestKit.read(_buffer())
	check_eq(sprites[0]["tint"], Color(0.4, 0.4, 0.4, 0.5))
	check_eq(sprites[1]["tint"], Color.WHITE)
	_rows.change_decor(first, _wide, Vector2(0.0, -2.0), Color.RED)
	check_eq(_drawn(), PackedStringArray(["wide at (290.0, 130.0)", "small at (430.0, 150.0)"]))
	check_eq(BatchTestKit.read(_buffer())[0]["tint"], Color.RED)
	check(_rows.has_decor(first), "the first is there")
	_rows.remove_decor(first)
	check(not _rows.has_decor(first), "the first is gone")
	check(_rows.has_decor(second), "the second stays")
	check_eq(_drawn(), PackedStringArray(["small at (430.0, 150.0)"]))
	_rows.remove_decor(second)
	check_eq(_rows.decor_count(), 0)
	check_eq(_drawn().size(), 0)


func test_every_change_to_decor_makes_the_batch_send_again() -> void:
	var serial := _rows.serial()
	var decor := _rows.add_decor(Vector2i(2, 3), _small)
	check(_rows.serial() > serial, "after add")
	serial = _rows.serial()
	_rows.tint_decor(decor, Color.RED)
	check(_rows.serial() > serial, "after tint")
	serial = _rows.serial()
	_rows.change_decor(decor, _wide)
	check(_rows.serial() > serial, "after change")
	serial = _rows.serial()
	_rows.remove_decor(decor)
	check(_rows.serial() > serial, "after remove")


func test_front_decor_on_an_empty_row_is_sent_only_while_that_row_is_on_screen() -> void:
	_rows.add_decor(Vector2i(2, 3), _small)
	var buffer := PackedFloat32Array()
	check_eq(_rows.assemble(Rect2(0.0, 100.0, 800.0, 100.0), buffer), 1, "the row is in view")
	check_eq(_rows.assemble(Rect2(0.0, 600.0, 800.0, 100.0), buffer), 0, "the row is above the view")
	check_eq(_rows.assemble(Rect2(0.0, -600.0, 800.0, 100.0), buffer), 0, "it is below the view")


func test_a_tall_front_decor_sprite_is_sent_when_only_its_top_is_on_screen() -> void:
	_rows.add_decor(Vector2i(2, 3), _tall, BatchTestKit.TALL_OFFSET)
	var buffer := PackedFloat32Array()
	check_eq(_rows.assemble(Rect2(0.0, -200.0, 800.0, 100.0), buffer), 1)


func test_decor_under_and_over_everything_is_always_sent() -> void:
	_rows.add_decor(Vector2i(2, 3), _small, Vector2.ZERO, Color.WHITE, BatchRows.UNDER)
	_rows.add_decor(Vector2i(2, 3), _small, Vector2.ZERO, Color.WHITE, BatchRows.OVER)
	var buffer := PackedFloat32Array()
	check_eq(_rows.assemble(Rect2(0.0, 900.0, 800.0, 100.0), buffer), 2)


func test_decor_with_a_wrong_layer_or_sprite_is_refused() -> void:
	check_eq(_rows.add_decor(Vector2i(2, 3), _small, Vector2.ZERO, Color.WHITE, 7), BatchRows.NO_DECOR)
	check_eq(_rows.add_decor(Vector2i(2, 3), 999), BatchRows.NO_DECOR)
	check_eq(_rows.decor_count(), 0)


func _buffer() -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	_rows.assemble(BatchTestKit.everything(), buffer)
	return buffer


## What is drawn, back to front: the name of each sprite and its middle.
func _drawn() -> PackedStringArray:
	var names := {_small: "small", _tall: "tall", _wide: "wide"}
	var drawn := PackedStringArray()
	for sprite in BatchTestKit.read(_buffer()):
		drawn.append("%s at %s" % [names[sprite["sprite"]], sprite["middle"]])
	return drawn
