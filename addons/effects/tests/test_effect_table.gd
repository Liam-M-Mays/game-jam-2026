extends GameTest
## Checks the table the effect shader reads: one line of numbers per effect number.


func test_line_zero_means_no_effect_and_is_never_handed_out() -> void:
	var table := EffectTable.new()
	check_eq(EffectTable.NONE, 0)
	check_eq(table.take(), 1)
	check_eq(table.take(), 2)
	check_eq(table.take(), 3)
	check_eq(table.lines_in_use(), 3)


func test_a_line_holds_nine_pixels_of_four_numbers() -> void:
	var table := EffectTable.new()
	var line := table.take()
	for texel in EffectTable.TEXELS:
		table.write(line, texel, texel + 0.25, texel + 0.5, texel + 0.75, -1.0)
	for texel in EffectTable.TEXELS:
		check_eq(table.read(line, texel), Vector4(texel + 0.25, texel + 0.5, texel + 0.75, -1.0))
	check_eq(EffectTable.TEXELS, 9)
	check_eq(EffectTable.NUMBERS, 36)


func test_a_line_that_is_given_back_is_wiped_and_handed_out_again() -> void:
	var table := EffectTable.new()
	var first := table.take()
	var second := table.take()
	table.write(first, 3, 1.0, 2.0, 3.0, 4.0)
	table.give_back(first)
	check_eq(table.read(first, 3), Vector4.ZERO)
	check_eq(table.lines_in_use(), 1)
	check_eq(table.take(), first)
	check_eq(table.take(), second + 1)


func test_giving_back_line_zero_or_a_line_never_handed_out_does_nothing() -> void:
	var table := EffectTable.new()
	table.take()
	table.give_back(EffectTable.NONE)
	table.give_back(50)
	check_eq(table.lines_in_use(), 1)
	check_eq(table.take(), 2)


func test_the_table_grows_and_keeps_its_numbers() -> void:
	var table := EffectTable.new()
	check_eq(table.line_count(), EffectTable.START_LINES)
	var first := table.take()
	table.write(first, 0, 9.0, 8.0, 7.0, 6.0)
	for more in EffectTable.START_LINES:
		table.take()
	check_eq(table.line_count(), EffectTable.START_LINES * 2)
	check_eq(table.lines_in_use(), EffectTable.START_LINES + 1)
	check_eq(table.read(first, 0), Vector4(9.0, 8.0, 7.0, 6.0))


func test_the_texture_has_one_row_per_line_in_full_precision() -> void:
	var table := EffectTable.new()
	var line := table.take()
	table.write(line, 2, 1000001.0, 0.001, -3.0, 44.5)
	var image := table.texture().get_image()
	check_eq(image.get_size(), Vector2i(EffectTable.TEXELS, EffectTable.START_LINES))
	check_eq(image.get_format(), Image.FORMAT_RGBAF)
	var pixel := image.get_pixel(2, line)
	check_eq(pixel.r, 1000001.0, "a big whole number stays exact")
	check_near(pixel.g, 0.001, 0.0000001)
	check_eq(pixel.b, -3.0)
	check_eq(pixel.a, 44.5)


func test_the_texture_is_only_built_again_after_a_change() -> void:
	var table := EffectTable.new()
	var line := table.take()
	check(table.is_dirty(), "a new table has to be sent")
	var texture := table.texture()
	check(not table.is_dirty(), "after it was asked for, it is clean")
	check_eq(table.texture(), texture)
	table.write(line, 0, 1.0, 0.0, 0.0, 0.0)
	check(table.is_dirty(), "a write makes it dirty")
	check_eq(table.texture(), texture, "the same texture is filled again, not a new one")
	check(not table.is_dirty(), "and it is clean again")
	table.give_back(line)
	check(table.is_dirty(), "giving a line back makes it dirty too")


func test_a_table_that_grew_gets_a_texture_of_the_new_size() -> void:
	var table := EffectTable.new()
	var small := table.texture()
	for more in EffectTable.START_LINES:
		table.take()
	var big := table.texture()
	check(big != small, "a new texture")
	check_eq(big.get_height(), EffectTable.START_LINES * 2)
