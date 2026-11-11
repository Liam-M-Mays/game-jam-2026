extends GameTest
## Checks the edges of the effect bookkeeping: a sprite number that is used
## again, a mover that was not placed yet, and a full effect table.

const STEP := EffectsTestKit.STEP
const TREE := 1
const HOUSE := 2
const MEEPLE := 0
## The first thing number of the crowd that fills the table.
const CROWD := 1000
## Every line a table can hand out: line 0 means "no effect".
const FULL := EffectTable.MAX_LINES - 1

var _rows: BatchRows
var _effects: SpriteEffects
var _tree: int
var _house: int
var _meeple: int
var _small: int
var _tall: int
var _wide: int


func before_each() -> void:
	_rows = EffectsTestKit.rows()
	_small = _rows.atlas.find(BatchTestKit.SMALL)
	_tall = _rows.atlas.find(BatchTestKit.TALL)
	_wide = _rows.atlas.find(BatchTestKit.WIDE)
	_rows.add_thing(TREE, Vector2i(2, 3), _tall, BatchTestKit.TALL_OFFSET)
	_rows.add_thing(HOUSE, Vector2i(6, 5), _wide, Vector2(3.5, -3.0))
	_rows.resize_movers(1)
	_place(MEEPLE)
	_effects = SpriteEffects.new(_rows, EffectsTestKit.style())
	_tree = SpriteEffects.thing(TREE)
	_house = SpriteEffects.thing(HOUSE)
	_meeple = SpriteEffects.mover(MEEPLE)


func after_each() -> void:
	_effects.close()


func test_every_effect_shows_on_a_thing_number_that_is_used_again() -> void:
	# The old thing leaves selected, and nobody calls forget. The new thing
	# with the same number starts with no effect number.
	for effect: String in ["flash", "hover", "select", "grow_in"]:
		_effects.select(_tree, true, Color.RED)
		_rows.remove_thing(TREE)
		_rows.add_thing(TREE, Vector2i(4, 4), _small)
		check_eq(_rows.thing_extra(TREE), 0.0, effect + ": the new thing carries no number")
		match effect:
			"hover":
				_effects.hover(_tree, true)
			"select":
				_effects.select(_tree, true, Color.RED)
			_:
				_effects.call(effect, _tree)
		var line := _effects.line_of(_tree)
		check(line != EffectTable.NONE, effect + ": it has a line")
		check_eq(_rows.thing_extra(TREE), float(line), effect + ": and the new thing carries it")
		var want_bits := 1.0 if effect == "hover" else (2.0 if effect == "select" else 0.0)
		var bits := _effects.table().read(line, 0).x
		check_eq(bits, want_bits, effect + ": the old thing's outline did not come along")
		_effects.forget(_tree)
	check_eq(_effects.table().lines_in_use(), 0)


func test_a_mover_number_used_again_after_a_resize_starts_with_no_effect() -> void:
	_effects.hover(_meeple, true)
	_rows.resize_movers(0)
	_rows.resize_movers(1)
	_place(MEEPLE)
	check_eq(_rows.mover_extra(MEEPLE), 0.0)
	_effects.select(_meeple, true)
	var line := _effects.line_of(_meeple)
	check(line != EffectTable.NONE)
	check_eq(_rows.mover_extra(MEEPLE), float(line), "the new meeple shows its own effect")
	check_eq(_effects.table().read(line, 0).x, 2.0, "selected, and not hovered like the old one")
	check_eq(_effects.table().lines_in_use(), 1, "the old one's line was given back")


func test_a_mover_that_is_placed_again_keeps_its_effect_until_forget() -> void:
	# A view that hands a mover number to another meeple must call forget.
	_effects.hover(_meeple, true)
	_rows.place_mover(MEEPLE, Vector2(900.0, 300.0), Color.WHITE, Vector4(float(_small), 0, 0, 1))
	check_eq(_rows.mover_extra(MEEPLE), float(_effects.line_of(_meeple)), "still hovered")
	_effects.forget(_meeple)
	check_eq(_rows.mover_extra(MEEPLE), 0.0)
	check(not _effects.has_effect(_meeple))


func test_a_mover_that_is_not_placed_yet_gets_no_effect() -> void:
	_rows.resize_movers(2)
	var late := SpriteEffects.mover(1)
	_effects.select(late, true)
	_effects.grow_in(late)
	check(not _effects.has_effect(late), "it is refused, like a sprite that is not in the batch")
	check_eq(_effects.table().lines_in_use(), 0)
	_place(1)
	_effects.select(late, true)
	check(_effects.line_of(late) != EffectTable.NONE, "once it is placed it takes effects")
	check_eq(_rows.mover_extra(1), float(_effects.line_of(late)))


func test_the_table_fills_to_16383_lines_and_empties_again() -> void:
	_add_crowd(FULL + 1)
	_flash_crowd(FULL)
	var table := _effects.table()
	check_eq(FULL, 16383)
	check_eq(table.lines_in_use(), FULL)
	check_eq(table.line_count(), EffectTable.MAX_LINES)
	check_eq(_effects.line_of(SpriteEffects.thing(CROWD + FULL - 1)), FULL, "the last line there is")
	check_eq(_rows.thing_extra(CROWD + FULL - 1), float(FULL), "it is exact on the sprite")
	check_eq(table.texture().get_size(), Vector2(EffectTable.TEXELS, EffectTable.MAX_LINES))
	var one_more := SpriteEffects.thing(CROWD + FULL)
	_effects.flash(one_more)
	check_eq(_effects.line_of(one_more), EffectTable.NONE, "no line is left for one more")
	check_eq(_rows.thing_extra(CROWD + FULL), 0.0, "so it is not shown")
	check(_effects.has_effect(one_more), "its flash still runs in the books")
	check_eq(_effects.waiting_count(), 1, "the toolkit says one sprite is short of a line")
	_run(96)
	check_eq(table.lines_in_use(), 0, "every line came back")
	check_eq(_effects.waiting_count(), 0)
	check_eq(_effects.active_count(), 0)
	_effects.flash(one_more)
	check(_effects.line_of(one_more) != EffectTable.NONE, "and the table takes effects again")
	check_eq(_rows.thing_extra(CROWD + FULL), float(_effects.line_of(one_more)))


func test_a_lasting_effect_asked_for_at_a_full_table_shows_when_a_line_comes_free() -> void:
	_add_crowd(FULL)
	_flash_crowd(FULL)
	_effects.select(_tree, true)
	_effects.hover(_house, true)
	check_eq(_effects.line_of(_tree), EffectTable.NONE, "the table is full")
	check_eq(_rows.thing_extra(TREE), 0.0)
	check_eq(_effects.waiting_count(), 2)
	_run(96)
	check_eq(_effects.waiting_count(), 0, "nobody waits any more")
	var tree_line := _effects.line_of(_tree)
	var house_line := _effects.line_of(_house)
	check(tree_line != EffectTable.NONE and house_line != EffectTable.NONE, "both got a line")
	check_eq(_rows.thing_extra(TREE), float(tree_line), "the tree carries its line now")
	check_eq(_rows.thing_extra(HOUSE), float(house_line))
	check_eq(_effects.table().read(tree_line, 0).x, 2.0, "selected")
	check_eq(_effects.table().read(house_line, 0).x, 1.0, "hovered")
	check_eq(_effects.table().lines_in_use(), 2)


func test_asking_again_once_the_table_has_room_gives_the_line() -> void:
	_add_crowd(FULL)
	_flash_crowd(FULL)
	_effects.select(_tree, true)
	_effects.hover(_house, true)
	_effects.select(_tree, true)
	check_eq(_effects.line_of(_tree), EffectTable.NONE, "still full: asking again changes nothing")
	_effects.forget(SpriteEffects.thing(CROWD))
	_effects.select(_tree, true)
	check(_effects.line_of(_tree) != EffectTable.NONE, "asked again with room: it has a line")
	check_eq(_rows.thing_extra(TREE), float(_effects.line_of(_tree)))
	_effects.forget(SpriteEffects.thing(CROWD + 1))
	_effects.hover(_house, true)
	check_eq(_rows.thing_extra(HOUSE), float(_effects.line_of(_house)), "the same for hover")
	check(_effects.line_of(_house) != EffectTable.NONE)


func test_at_a_full_table_a_selected_sprite_keeps_its_outline_while_it_flashes() -> void:
	_effects.select(_tree, true)
	_effects.select(_house, true)
	var shared := _effects.line_of(_tree)
	check_eq(_effects.line_of(_house), shared, "the two selected sprites share a line")
	_add_crowd(FULL - 1)
	_flash_crowd(FULL - 1)
	check_eq(_effects.table().lines_in_use(), FULL)
	_effects.flash(_tree)
	check_eq(_effects.line_of(_tree), shared, "no line of its own to be had: it stays")
	check_eq(_rows.thing_extra(TREE), float(shared), "so its outline is still drawn")
	check_eq(_rows.thing_extra(HOUSE), float(shared))
	check_eq(_effects.pose(_tree)["flash"], 1.0, "the flash runs in the books")
	check_eq(_effects.waiting_count(), 1, "it waits for a line of its own")
	# Alone on its shared line, a sprite turns that line into its own.
	_effects.forget(_house)
	_effects.flash(_tree)
	var own := _effects.line_of(_tree)
	check(own != EffectTable.NONE, "it has a line")
	check_eq(_rows.thing_extra(TREE), float(own))
	check_eq(_effects.table().read(own, 0).x, 2.0, "still selected")
	check(_effects.table().read(own, 3).w >= 0.0, "and the flash is on the line now")
	_run(96)
	check_eq(_effects.table().lines_in_use(), 1, "afterwards only the selected line is left")
	check_eq(_rows.thing_extra(TREE), float(_effects.line_of(_tree)))


func _place(index: int) -> void:
	_rows.place_mover(index, Vector2(100.0, 100.0), Color.WHITE, Vector4(float(_small), 0, 0, 1))


## Adds [param count] small things, 128 to a row.
func _add_crowd(count: int) -> void:
	for index in count:
		@warning_ignore("integer_division")
		_rows.add_thing(CROWD + index, Vector2i(127 - index % 128, index / 128 - 70), _small)


## Starts a flash on the first [param count] things of the crowd.
func _flash_crowd(count: int) -> void:
	for index in count:
		_effects.flash(SpriteEffects.thing(CROWD + index))


func _run(frames: int) -> void:
	for frame in frames:
		_effects.advance(STEP)
