extends GameTest
## Checks that the grid numbers the dev scenes use are the jam game's
## slanted six-neighbour grid, and that art is drawn the jam game's way.

## The six neighbours of a cell in the jam game, from its grid script.
const JAM_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, -1), Vector2i(-1, 1),
]


func test_a_cell_is_where_the_jam_grid_puts_it() -> void:
	var cells := JamGrid.cells()
	# The jam game: ((x * 7 + y * 5) * 10, y * 5 * 10), with a cell scale of 10.
	for x in range(-3, 50, 7):
		for y in range(-3, 50, 7):
			check_eq(cells.position_of(Vector2i(x, y)), Vector2((x * 7 + y * 5) * 10, y * 5 * 10))


func test_a_point_finds_the_cell_the_jam_grid_finds() -> void:
	var cells := JamGrid.cells()
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	for sample in 2000:
		var point := Vector2(rng.randf_range(-800.0, 6000.0), rng.randf_range(-800.0, 2600.0))
		check_eq(cells.cell_at(point), _jam_coords_at(point))


func test_the_six_nearest_cells_are_the_jam_neighbours() -> void:
	var cells := JamGrid.cells()
	var home := Vector2i(10, 10)
	var around: Array[Vector2i] = []
	for x in range(-3, 4):
		for y in range(-3, 4):
			if x != 0 or y != 0:
				around.append(Vector2i(x, y))
	var here := cells.position_of(home)
	around.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var far_a := here.distance_to(cells.position_of(home + a))
		var far_b := here.distance_to(cells.position_of(home + b))
		return far_a < far_b)
	var nearest := around.slice(0, 6)
	for neighbour in JAM_NEIGHBOURS:
		check(nearest.has(neighbour), "%s is not one of the six nearest cells" % neighbour)


func test_art_is_drawn_at_ten_times_its_size() -> void:
	check_eq(JamGrid.ART_SCALE, 10.0)
	var atlas := SpriteAtlas.new()
	var art := StressArt.new()
	art.add_to(atlas)
	atlas.build()
	var rows := JamGrid.rows(atlas, Rect2(0.0, 0.0, 2000.0, 2000.0))
	check_eq(rows.pixel_scale, 10.0)
	# The jam Town Hall: 16 by 32 art pixels, with an offset of (3, -13).
	rows.add_thing(1, Vector2i(4, 6), art.sprites[&"town_hall"], art.offset_of(&"town_hall"))
	var buffer := PackedFloat32Array()
	rows.assemble(Rect2(-5000.0, -5000.0, 10000.0, 10000.0), buffer)
	check_eq(Vector2(buffer[0], buffer[5]), Vector2(160.0, 320.0))
	var cell_position := JamGrid.cells().position_of(Vector2i(4, 6))
	check_eq(Vector2(buffer[3], buffer[7]), cell_position + Vector2(30.0, -130.0))


func test_art_is_drawn_with_crisp_pixels_on_the_opengl_renderer() -> void:
	var filter_setting := "rendering/textures/canvas_textures/default_texture_filter"
	check_eq(ProjectSettings.get_setting(filter_setting), 0)
	check_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")
	var atlas := SpriteAtlas.new()
	var look := MeepleLook.new()
	look.add_to(atlas)
	atlas.build()
	var batch := SpriteBatch.new()
	batch.setup(JamGrid.rows(atlas, Rect2(0.0, 0.0, 100.0, 100.0)), MeepleLook.SHADER)
	var drawer := batch.get_child(0) as MultiMeshInstance2D
	check_eq(drawer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	batch.free()


## The jam game's own sum, from its grid script. The cell scale is 10 and the
## cell picture has an offset of (-0.5, 0).
func _jam_coords_at(point: Vector2) -> Vector2i:
	var cell_scale := Vector2(10.0, 10.0)
	var pos := point - Vector2(-0.5, 0.0) * cell_scale
	var y := roundi(pos.y / (cell_scale.y * 5))
	var x := roundi((pos.x - 5 * y * cell_scale.x) / (cell_scale.x * 7))
	return Vector2i(x, y)
