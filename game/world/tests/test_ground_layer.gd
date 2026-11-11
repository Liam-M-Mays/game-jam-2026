extends GameTest
## Checks the ground picture: its map has one pixel per cell with the band of
## that cell, and its shader gets the numbers of the village grid.

var _view: VillageView


func after_each() -> void:
	if _view != null:
		_view.free()


func test_a_row_is_slanted_by_whole_cells() -> void:
	check_eq(GroundLayer.slant_of(0), 0)
	check_eq(GroundLayer.slant_of(1), 0)
	check_eq(GroundLayer.slant_of(2), 1)
	check_eq(GroundLayer.slant_of(7), 5)
	check_eq(GroundLayer.slant_of(-1), -1)
	check_eq(GroundLayer.slant_of(-7), -5)


func test_the_band_map_has_one_pixel_per_cell() -> void:
	var made := WorldTestKit.village(31)
	var world := GroundWorld.of(made)
	var read := GroundLayer.band_map(made.grid, world.bounds)
	var image: Image = read["image"]
	var origin: Vector2i = read["origin"]
	check_eq(image.get_format(), Image.FORMAT_R8)
	for cell in WorldTestKit.cells_of(made):
		var at := Vector2i(cell.x + GroundLayer.slant_of(cell.y), cell.y) - origin
		var ground := roundi(image.get_pixelv(at).r * 255.0)
		if ground != made.grid.ground(cell):
			fail("cell %s has ground %d, the map says %d" % [cell, made.grid.ground(cell), ground])
			break
	var filled := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).r > 0.0:
				filled += 1
	check_eq(filled, world.cells, "pixels of the map that are a cell")
	check(image.get_width() < 70 and image.get_height() < 80, "the map is a box round the world")


func test_the_shader_gets_the_numbers_of_the_grid_and_the_table() -> void:
	var made := WorldTestKit.village(32, 500)
	var world := GroundWorld.of(made)
	var layers := VillageLayers.of(made)
	_view = VillageView.new()
	tree.current_scene.add_child(_view)
	_view.attach(made, world.bounds, layers)
	var ground := _view.get_node("Ground") as Polygon2D
	var material := ground.material as ShaderMaterial
	check_eq(material.shader, GroundLayer.SHADER)
	check_eq(material.get_shader_parameter(&"art_scale"), VillageView.ART_SCALE)
	check_eq(material.get_shader_parameter(&"grid_numbers"), Vector3i(7, 5, 5))
	check_eq(material.get_shader_parameter(&"cell_middle"), Vector2(-0.5, 0.0))
	check_eq(material.get_shader_parameter(&"ground_colour"), world.recipe.ground_colour)
	var colours: PackedColorArray = material.get_shader_parameter(&"band_colours")
	check_eq(colours[0], world.recipe.bands[0].colour)
	check_eq(colours[1], world.recipe.bands[1].colour)
	check_eq(material.get_shader_parameter(&"show_bands"), false, "the ground starts flat")
	(layers[0] as GroundLayer).show_bands = true
	check_eq(material.get_shader_parameter(&"show_bands"), true)
	var area := Rect2(ground.polygon[0], ground.polygon[2] - ground.polygon[0])
	var corner := VillageView.to_pixels(world.bounds.position)
	var cells := Rect2(corner, VillageView.to_pixels(world.bounds.size))
	check(area.encloses(cells), "the rectangle covers every cell")
