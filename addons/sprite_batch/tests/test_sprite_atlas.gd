extends GameTest
## Checks that the atlas puts every sprite on one image and keeps its pixels.


func test_every_sprite_keeps_its_pixels() -> void:
	var atlas := SpriteAtlas.new()
	var sources: Array[Image] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for index in 40:
		var image := _noise(rng.randi_range(1, 20), rng.randi_range(1, 34), rng)
		sources.append(image)
		check_eq(atlas.add_image("sprite_%d" % index, image), index)
	atlas.build()
	check(atlas.is_built(), "the atlas was not built")
	var wrong := 0
	for index in sources.size():
		var rect := atlas.rect_of(index)
		check_eq(rect.size, sources[index].get_size())
		for y in rect.size.y:
			for x in rect.size.x:
				var want := sources[index].get_pixel(x, y)
				if not atlas.image().get_pixelv(rect.position + Vector2i(x, y)).is_equal_approx(want):
					wrong += 1
	check_eq(wrong, 0, "pixels that changed on the way into the atlas")


func test_no_two_sprites_touch() -> void:
	var atlas := SpriteAtlas.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for index in 60:
		atlas.add_image("s%d" % index, _noise(rng.randi_range(1, 16), rng.randi_range(1, 32), rng))
	atlas.build()
	var whole := Rect2i(Vector2i.ZERO, atlas.image().get_size())
	for a in atlas.sprite_count():
		check(whole.encloses(atlas.rect_of(a)), "sprite %d is off the image" % a)
		for b in range(a + 1, atlas.sprite_count()):
			if atlas.rect_of(a).grow(SpriteAtlas.PADDING).intersects(atlas.rect_of(b)):
				fail("sprites %d and %d touch" % [a, b])


func test_a_sprite_can_be_a_part_of_an_image() -> void:
	var atlas := SpriteAtlas.new()
	var sheet := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	sheet.set_pixel(5, 3, Color.RED)
	sheet.set_pixel(6, 4, Color.BLUE)
	var id := atlas.add_image(&"part", sheet, Rect2i(5, 3, 2, 2))
	atlas.build()
	check_eq(atlas.size_of(id), Vector2i(2, 2))
	var at := atlas.rect_of(id).position
	check(atlas.image().get_pixelv(at).is_equal_approx(Color.RED), "top left pixel")
	check(atlas.image().get_pixelv(at + Vector2i(1, 1)).is_equal_approx(Color.BLUE), "bottom right")


func test_a_name_gets_one_number() -> void:
	var atlas := SpriteAtlas.new()
	var image := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	var first := atlas.add_image(&"rock", image)
	check_eq(atlas.add_image(&"rock", image), first)
	check_eq(atlas.find(&"rock"), first)
	check_eq(atlas.find(&"nothing"), SpriteAtlas.NO_SPRITE)
	check_eq(atlas.sprite_count(), 1)
	check(atlas.has_sprite(first), "the sprite is known")
	check(not atlas.has_sprite(1), "a number that was never given out is not known")


func test_a_name_cannot_be_given_to_another_picture() -> void:
	var atlas := SpriteAtlas.new()
	var sheet := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	var other := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	var first := atlas.add_image(&"wood", sheet, Rect2i(0, 0, 3, 1))
	# The same picture again: the same number.
	check_eq(atlas.add_image(&"wood", sheet, Rect2i(0, 0, 3, 1)), first)
	# Another region, or another image, under the same name: refused. Each
	# refusal also logs an error, which shows as a warning in the test run.
	check_eq(atlas.add_image(&"wood", sheet, Rect2i(0, 0, 2, 2)), SpriteAtlas.NO_SPRITE)
	check_eq(atlas.add_image(&"wood", other), SpriteAtlas.NO_SPRITE)
	check_eq(atlas.sprite_count(), 1)
	check_eq(atlas.find(&"wood"), first)
	atlas.build()
	check_eq(atlas.size_of(first), Vector2i(3, 1))


func test_only_solid_pixels_are_solid() -> void:
	var atlas := SpriteAtlas.new()
	var image := Image.create_empty(3, 2, false, Image.FORMAT_RGBA8)
	image.set_pixel(1, 0, Color.WHITE)
	var id := atlas.add_image(&"dot", image)
	atlas.build()
	check(atlas.is_solid(id, Vector2i(1, 0)), "the painted pixel is solid")
	check(not atlas.is_solid(id, Vector2i(0, 0)), "a see-through pixel is not solid")
	check(not atlas.is_solid(id, Vector2i(3, 0)), "a pixel outside is not solid")
	check(not atlas.is_solid(id, Vector2i(1, -1)), "a pixel above is not solid")


func test_the_shader_table_lists_every_sprite() -> void:
	var atlas := BatchTestKit.atlas()
	check(atlas.texture() != null, "the atlas has a texture")
	var table := atlas.rects_texture()
	check(table != null, "the atlas has a table for the shader")
	check_eq(table.get_width(), atlas.sprite_count())
	check_eq(table.get_height(), 1)


func test_adding_after_building_keeps_the_numbers() -> void:
	var atlas := BatchTestKit.atlas()
	var small := atlas.find(BatchTestKit.SMALL)
	var size := atlas.size_of(small)
	var extra := atlas.add_image(&"extra", Image.create_empty(9, 9, false, Image.FORMAT_RGBA8))
	check(not atlas.is_built(), "a new sprite means the atlas must be built again")
	atlas.build()
	check_eq(atlas.find(BatchTestKit.SMALL), small)
	check_eq(atlas.size_of(small), size)
	check_eq(atlas.size_of(extra), Vector2i(9, 9))


func _noise(width: int, height: int, rng: RandomNumberGenerator) -> Image:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			image.set_pixel(x, y, Color8(rng.randi() % 256, rng.randi() % 256, rng.randi() % 256))
	return image
