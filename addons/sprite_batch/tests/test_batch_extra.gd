extends GameTest
## Checks the extra number: one more number every sprite carries, next to its
## colour and its four shader numbers. The effects toolkit keeps its effect
## number there.

## Where the extra number sits among the 16 numbers of a sprite.
const EXTRA_AT := 2

var _rows: BatchRows
var _atlas: SpriteAtlas
var _small: int
var _tall: int


func before_each() -> void:
	_atlas = BatchTestKit.atlas()
	_small = _atlas.find(BatchTestKit.SMALL)
	_tall = _atlas.find(BatchTestKit.TALL)
	var world := Rect2(-2000.0, -2000.0, 4000.0, 4000.0)
	_rows = BatchRows.new(BatchTestKit.cells(), _atlas, world, BatchTestKit.ART_SCALE)
	_rows.shape_movers(Vector2(30.0, 60.0), Vector2(0.0, -20.0))


func test_a_new_thing_has_the_extra_number_zero() -> void:
	_rows.add_thing(1, Vector2i(2, 3), _small)
	check_eq(_rows.thing_extra(1), 0.0)
	check_eq(_buffer()[EXTRA_AT], 0.0)


func test_the_extra_number_is_the_third_number_of_the_sprite_and_changes_nothing_else() -> void:
	_rows.add_thing(1, Vector2i(2, 3), _small, BatchTestKit.SMALL_OFFSET, Color(0.1, 0.2, 0.3))
	var before := _buffer()
	_rows.set_thing_extra(1, 7.0)
	var after := _buffer()
	check_eq(_rows.thing_extra(1), 7.0)
	check_eq(after.size(), BatchRows.FLOATS)
	for index in BatchRows.FLOATS:
		var want := 7.0 if index == EXTRA_AT else before[index]
		check_eq(after[index], want, "number %d of the sprite" % index)


func test_the_extra_number_stays_exact_far_past_the_sixteen_bit_limit() -> void:
	_rows.add_thing(1, Vector2i(2, 3), _small)
	_rows.set_thing_extra(1, 1000001.0)
	check_eq(_buffer()[EXTRA_AT], 1000001.0)


func test_setting_it_rebuilds_only_the_row_of_the_thing() -> void:
	_rows.add_thing(1, Vector2i(2, 3), _small)
	_rows.add_thing(2, Vector2i(2, 4), _small)
	var row_3 := _rows.row_version(3)
	var row_4 := _rows.row_version(4)
	var serial := _rows.serial()
	_rows.set_thing_extra(1, 5.0)
	check_eq(_rows.row_version(3), row_3 + 1)
	check_eq(_rows.row_version(4), row_4)
	check(_rows.serial() > serial, "the batch knows it has to send the sprites again")


func test_it_belongs_to_one_thing_and_not_to_its_neighbour() -> void:
	_rows.add_thing(1, Vector2i(2, 3), _small)
	_rows.add_thing(2, Vector2i(3, 3), _small)
	_rows.set_thing_extra(2, 9.0)
	check_eq(_rows.thing_extra(1), 0.0)
	check_eq(_rows.thing_extra(2), 9.0)


func test_change_thing_keeps_the_extra_number() -> void:
	_rows.add_thing(1, Vector2i(2, 3), _small)
	_rows.set_thing_extra(1, 4.0)
	_rows.change_thing(1, _tall, BatchTestKit.TALL_OFFSET, Color.RED)
	check_eq(_rows.thing_extra(1), 4.0)
	check_eq(BatchTestKit.read(_buffer())[0]["sprite"], _tall)


func test_a_thing_that_is_not_there_has_none_and_takes_none() -> void:
	_rows.set_thing_extra(99, 3.0)
	check_eq(_rows.thing_extra(99), 0.0)
	check_eq(_rows.thing_count(), 0)


func test_a_mover_carries_an_extra_number_too() -> void:
	_rows.resize_movers(2)
	_rows.place_mover(0, Vector2(100.0, 100.0), Color.WHITE, Vector4(float(_small), 0, 0, 1))
	_rows.place_mover(1, Vector2(300.0, 100.0), Color.WHITE, Vector4(float(_small), 0, 0, 1))
	_rows.set_mover_extra(1, 12.0)
	check_eq(_rows.mover_extra(0), 0.0)
	check_eq(_rows.mover_extra(1), 12.0)
	var extras := PackedFloat32Array()
	var buffer := _buffer()
	for at in range(0, buffer.size(), BatchRows.FLOATS):
		extras.append(buffer[at + EXTRA_AT])
	extras.sort()
	check_eq(extras, PackedFloat32Array([0.0, 12.0]))


func test_a_mover_that_was_not_placed_yet_has_none_and_takes_none() -> void:
	_rows.resize_movers(1)
	_rows.set_mover_extra(0, 6.0)
	check_eq(_rows.mover_extra(0), 0.0)
	_rows.place_mover(0, Vector2(100.0, 100.0), Color.WHITE, Vector4(float(_small), 0, 0, 1))
	check_eq(_rows.mover_extra(0), 0.0)


func test_a_mover_keeps_it_through_every_other_change() -> void:
	_rows.resize_movers(1)
	_rows.place_mover(0, Vector2(100.0, 100.0), Color.WHITE, Vector4(float(_small), 0, 0, 1))
	_rows.set_mover_extra(0, 31.0)
	_rows.look_mover(0, Color.RED, Vector4(float(_tall), 1.5, 0.5, 2.0))
	check_eq(_rows.mover_extra(0), 31.0, "after look_mover")
	_rows.set_mover_number(0, 1, 3.25)
	check_eq(_rows.mover_extra(0), 31.0, "after set_mover_number")
	_rows.move_movers(PackedVector2Array([Vector2(101.0, 100.5)]))
	check_eq(_rows.mover_extra(0), 31.0, "after a small step")
	_rows.move_movers(PackedVector2Array([Vector2(900.0, 730.0)]))
	check_eq(_rows.mover_extra(0), 31.0, "after a walk into another band and column")
	_rows.place_mover(0, Vector2(-500.0, -300.0), Color.BLUE, Vector4(float(_small), 0, 0, 1))
	check_eq(_rows.mover_extra(0), 31.0, "after being placed again")
	check_eq(_buffer()[EXTRA_AT], 31.0)


func test_a_dropped_mover_does_not_leave_its_extra_number_to_the_next_one() -> void:
	_rows.resize_movers(1)
	_rows.place_mover(0, Vector2(100.0, 100.0), Color.WHITE, Vector4(float(_small), 0, 0, 1))
	_rows.set_mover_extra(0, 8.0)
	_rows.resize_movers(0)
	_rows.resize_movers(1)
	_rows.place_mover(0, Vector2(100.0, 100.0), Color.WHITE, Vector4(float(_small), 0, 0, 1))
	check_eq(_rows.mover_extra(0), 0.0)


func test_a_thing_tells_its_cell_its_cells_and_its_offset() -> void:
	var footprint: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 3)]
	_rows.add_thing(1, Vector2i(2, 3), _tall, Vector2(3.5, -3.0), Color.WHITE, footprint)
	_rows.add_thing(2, Vector2i(6, 1), _small)
	check_eq(_rows.thing_cell(1), Vector2i(2, 3))
	check_eq(_rows.thing_cells(1), footprint)
	check_eq(_rows.thing_cells(2), [Vector2i(6, 1)] as Array[Vector2i])
	check_eq(_rows.thing_cells(99), [] as Array[Vector2i])
	check_eq(_rows.thing_offset(1), Vector2(3.5, -3.0))
	check_eq(_rows.thing_offset(2), Vector2.ZERO)


func test_the_mover_offset_is_given_in_art_pixels() -> void:
	check_eq(_rows.mover_offset(), Vector2(0.0, -2.0))


func _buffer() -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	_rows.assemble(BatchTestKit.everything(), buffer)
	return buffer
