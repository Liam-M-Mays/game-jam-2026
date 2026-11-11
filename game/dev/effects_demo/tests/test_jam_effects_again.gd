extends GameTest
## Checks, with the jam game's numbers, what happens when an effect is
## started again while it runs, and where the spark burst is in the drawing
## order. Each test says what the jam game does. Those numbers were measured
## on the jam game's own scenes with their tweens.

const TREE := 1

var _rows: BatchRows
var _effects: SpriteEffects
var _jam := JamEffects.new()
var _tree: int
var _tree_sprite: int


func before_each() -> void:
	var atlas := SpriteAtlas.new()
	_jam.add_to(atlas)
	_tree_sprite = atlas.add_file(&"tree", StressArt.STARTER, Rect2i(37, 2, 6, 8))
	atlas.build()
	_rows = JamGrid.rows(atlas, Rect2(-2000.0, -2000.0, 4000.0, 4000.0))
	_add_tree(TREE, Vector2i(2, 3))
	_effects = SpriteEffects.new(_rows, JamEffects.style())
	_tree = SpriteEffects.thing(TREE)


func after_each() -> void:
	_effects.close()


func test_a_second_delivery_during_a_pop_does_not_snap_back() -> void:
	# building.gd tweens to 105% from the size the building has. With a
	# delivery every 0.03 seconds the jam hut climbs to 1.05 and stays there.
	_effects.pop(_tree)
	_effects.advance(0.03)
	check_near(_size(), 1.040451, 0.000001, "the jam hut after 0.03 seconds")
	_effects.pop(_tree)
	check_near(_size(), 1.040451, 0.000001, "the second delivery: the same size, no snap")
	_effects.advance(0.01)
	check_near(_size(), 1.043402, 0.000001, "the jam hut 0.01 seconds into the second pop")
	_effects.advance(0.02)
	var before := _size()
	for delivery in 20:
		_effects.pop(_tree)
		check(_size() >= before - 0.000001, "delivery %d: it never gets smaller" % delivery)
		_effects.advance(0.03)
		before = _size()
	check_near(_size(), 1.05, 0.0001, "it has climbed to 105% and stays")
	_effects.advance(0.02)
	check_near(_size(), 1.05, 0.000001, "the top of the last pop, 0.05 seconds after it began")
	_effects.advance(0.13)
	check(not _effects.has_effect(_tree), "and back to rest 0.13 seconds later")


func test_a_second_hit_during_a_wobble_carries_on_from_the_tilt_it_has() -> void:
	# harvestable.gd tweens to 3 degrees from the tilt the tree has.
	_jam.hit(_effects, _tree)
	_effects.advance(0.05)
	check_near(_tilt(), 2.4, 0.000001, "the jam tree 0.05 seconds into a hit")
	_jam.hit(_effects, _tree)
	check_near(_tilt(), 2.4, 0.000001, "the second hit: the same tilt, no snap upright")
	_effects.advance(0.001)
	check_near(_tilt(), 2.4096, 0.000001, "the jam tree 0.001 seconds later")
	_effects.advance(0.0615)
	check_near(_tilt(), 3.0, 0.000001, "full tilt one step after the second hit")
	_effects.advance(0.1875)
	check(not _effects.has_effect(_tree), "the second hit is over 0.25 seconds after it began")


func test_a_squash_a_flash_and_a_shake_start_over_as_in_the_jam_game() -> void:
	# These three set their start value before they tween, so they snap.
	_jam.hit(_effects, _tree)
	_effects.reject(_tree)
	_effects.advance(0.05)
	_jam.hit(_effects, _tree)
	_effects.reject(_tree)
	var pose := _effects.pose(_tree)
	check_eq(pose["scale"], Vector2(1.15, 0.85), "the squash starts squashed")
	check_eq(pose["flash"], 1.0, "the flash starts full")
	check_eq(pose["shift"], 0.0, "the shake starts from rest")


func test_the_sparks_are_behind_their_own_row_and_in_front_of_the_row_above() -> void:
	# grid_object.gd puts the sparks at the middle of the tree's picture, 30
	# pixels above the line the tree stands on, in a grid that sorts by
	# height. So a tree next to it on the same row covers them.
	_add_tree(2, Vector2i(3, 3))
	_add_tree(3, Vector2i(1, 3))
	_add_tree(4, Vector2i(2, 2))
	_add_tree(5, Vector2i(2, 4))
	_jam.sparks(_effects, TREE)
	var order := _drawn_rows()
	check_eq(order, PackedStringArray(["2", "sparks", "3", "3", "3", "4"]), "back to front, by row")
	var buffer := PackedFloat32Array()
	_rows.assemble(Rect2(-1e6, -1e6, 2e6, 2e6), buffer)
	var at := 1 * BatchRows.FLOATS
	var middle := JamGrid.cells().position_of(Vector2i(2, 3)) + Vector2(0.0, -30.0)
	check_eq(Vector2(buffer[at + 3], buffer[at + 7]), middle, "at the middle of the tree")
	# The tree breaks: the sparks play on in the same place.
	_rows.remove_thing(TREE)
	_effects.advance(0.07)
	check_eq(_drawn_rows(), PackedStringArray(["2", "sparks", "3", "3", "4"]))


func test_the_village_shader_compiles_with_the_effects_in_it() -> void:
	# A run with no window compiles a shader once it is on a material. A
	# shader that does not compile has no values.
	var material := ShaderMaterial.new()
	material.shader = MeepleLook.SHADER
	var known := PackedStringArray()
	for uniform: Dictionary in MeepleLook.SHADER.get_shader_uniform_list():
		known.append(uniform["name"])
	for wanted: String in ["effects_table", "effects_clock", "batch_turn_inverse", "batch_atlas"]:
		check(known.has(wanted), "the village shader has the value %s" % wanted)


func _add_tree(id: int, cell: Vector2i) -> void:
	_rows.add_thing(id, cell, _tree_sprite, Vector2(0.0, -3.0))


func _size() -> float:
	return _effects.pose(_tree)["scale"].x


func _tilt() -> float:
	return _effects.pose(_tree)["degrees"]


## What is drawn, back to front: the grid row of each tree, and "sparks".
func _drawn_rows() -> PackedStringArray:
	var drawn := PackedStringArray()
	var buffer := PackedFloat32Array()
	_rows.assemble(Rect2(-1e6, -1e6, 2e6, 2e6), buffer)
	for at in range(0, buffer.size(), BatchRows.FLOATS):
		if _jam.spark_sprites.has(int(buffer[at + 12])):
			drawn.append("sparks")
		else:
			var line := buffer[at + 7] + 30.0
			drawn.append(str(JamGrid.cells().band_at(line)))
	return drawn
