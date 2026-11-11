extends GameTest
## Checks the data files of the resource kinds: wood, stone and food.

## The jam game's cut-outs of the two drop pictures. They go with the old
## game in issue #36, and the comparison with them goes then too.
const JAM_PICTURES: Dictionary[StringName, String] = {
	&"wood": "res://assets/Res/wood.tres",
	&"stone": "res://assets/Res/rocks.tres",
}

var _kinds: Dictionary[StringName, ResourceKind] = {}


## Loads the data files for every test.
func before_each() -> void:
	for kind in ResourceKind.load_all():
		_kinds[kind.id] = kind


func test_the_kinds_are_wood_stone_and_food() -> void:
	var names: Array[StringName] = []
	var numbers: Array[int] = []
	for kind in ResourceKind.load_all():
		names.append(kind.id)
		numbers.append(kind.number)
	check_eq(names, [&"wood", &"stone", &"food"] as Array[StringName])
	check_eq(numbers, [1, 2, 3] as Array[int])


func test_wood_and_stone_are_items_and_food_is_a_banked_number() -> void:
	check(_kinds[&"wood"].is_item, "wood is an item")
	check(_kinds[&"stone"].is_item, "stone is an item")
	check(not _kinds[&"food"].is_item, "food is never an item")


func test_a_new_village_gets_10_food_and_food_has_a_base_cap_of_20() -> void:
	check_eq(_kinds[&"food"].start_amount, 10)
	check_eq(_kinds[&"food"].base_cap, 20)
	check_eq(_kinds[&"wood"].start_amount, 0)
	check_eq(_kinds[&"stone"].start_amount, 0)
	check_eq(_kinds[&"wood"].base_cap, 0)
	check_eq(_kinds[&"stone"].base_cap, 0)


func test_the_drop_pictures_are_the_regions_of_the_jam_game() -> void:
	check_eq(_kinds[&"wood"].sprite_region, Rect2i(1, 3, 3, 1))
	check_eq(_kinds[&"stone"].sprite_region, Rect2i(5, 3, 2, 1))
	check(ResourceLoader.exists(_kinds[&"wood"].sprite_file), "the wood art file is there")
	check(ResourceLoader.exists(_kinds[&"stone"].sprite_file), "the stone art file is there")
	check_eq(_kinds[&"food"].sprite_file, "")


func test_the_drop_pictures_have_the_same_pixels_as_the_jam_game() -> void:
	for id: StringName in JAM_PICTURES:
		var jam := load(JAM_PICTURES[id]) as AtlasTexture
		var jam_pixels := jam.atlas.get_image().get_region(Rect2i(jam.region))
		var kind := _kinds[id]
		var ours := (load(kind.sprite_file) as Texture2D).get_image()
		var our_pixels := ours.get_region(kind.sprite_region)
		check_eq(Rect2i(jam.region), kind.sprite_region, "%s: the same region" % id)
		check_eq(our_pixels.get_size(), jam_pixels.get_size(), "%s: the same size" % id)
		var differ := 0
		for x in jam_pixels.get_width():
			for y in jam_pixels.get_height():
				if our_pixels.get_pixel(x, y) != jam_pixels.get_pixel(x, y):
					differ += 1
		check_eq(differ, 0, "%s: pixels that differ from the jam game" % id)
		check(our_pixels.get_pixel(0, 0).a > 0.9, "%s: the picture is not empty" % id)
