extends GameTest
## Checks the data files of the five kinds of tree, rock and bush: the names,
## the footprints and the sprites of the jam game.

## The jam game's numbers: cells wide, the part of the art file, and the
## offset from the cell to the middle of the sprite.
const JAM: Dictionary[StringName, Array] = {
	&"tree": [1, Rect2i(37, 2, 6, 8), Vector2(0, -3)],
	&"rock": [1, Rect2i(54, 6, 4, 4), Vector2(0, -1)],
	&"big_tree": [2, Rect2i(18, 0, 10, 12), Vector2(3, -5)],
	&"bush": [2, Rect2i(0, 0, 16, 10), Vector2(3, -1)],
	&"big_rock": [2, Rect2i(67, 5, 10, 6), Vector2(3, -2)],
}


func test_there_are_five_kinds_in_the_order_of_the_jam_game() -> void:
	var names: Array[StringName] = []
	for kind in NatureKinds.all():
		names.append(kind.kind_name)
	check_eq(names, [&"tree", &"rock", &"big_tree", &"bush", &"big_rock"] as Array[StringName])
	check_eq(NatureKinds.FILES.size(), 5)


func test_each_kind_has_the_footprint_and_sprite_of_the_jam_game() -> void:
	for kind in NatureKinds.all():
		var jam: Array = JAM[kind.kind_name]
		check_eq(kind.width, jam[0], "%s: cells wide" % kind.kind_name)
		check_eq(kind.depth, 1, "%s: rows" % kind.kind_name)
		check_eq(kind.region, jam[1], "%s: the part of the art file" % kind.kind_name)
		check_eq(kind.offset, jam[2], "%s: the offset" % kind.kind_name)
		check(kind.sheet != null, "%s has an art file" % kind.kind_name)
		var size := Vector2i(kind.sheet.get_width(), kind.sheet.get_height())
		check(Rect2i(Vector2i.ZERO, size).encloses(kind.region), "%s: inside its file" % kind.kind_name)


func test_no_kind_uses_art_from_the_source_art_folder() -> void:
	for kind in NatureKinds.all():
		var path := kind.sheet.resource_path
		var in_game := path.begins_with("res://assets/") or path.begins_with("res://game/")
		check(in_game, "%s uses %s" % [kind.kind_name, path])


func test_a_kind_is_found_by_its_name() -> void:
	check_eq(NatureKinds.index_of(&"tree"), 0)
	check_eq(NatureKinds.index_of(&"big_rock"), 4)
	check_eq(NatureKinds.index_of(&"cactus"), NatureKinds.NO_KIND)
	check_eq(NatureKinds.find(&"bush").kind_name, &"bush")
	check(NatureKinds.find(&"cactus") == null, "an unknown name finds nothing")
	check(NatureKinds.all().is_read_only(), "the shared list cannot be changed")
