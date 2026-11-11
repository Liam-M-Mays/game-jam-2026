extends GameTest
## Checks the node that draws the batch: what it sends, when it sends, and
## that a screen position finds the right thing through the camera.

var _rows: BatchRows
var _batch: SpriteBatch
var _camera: Camera2D
var _cells := BatchCells.new()


func before_each() -> void:
	var atlas := BatchTestKit.atlas()
	_rows = BatchRows.new(_cells, atlas, Rect2(0.0, 0.0, 4000.0, 3000.0))
	for row in 40:
		for column in 40:
			var cell := Vector2i(column, row)
			var small := atlas.find(BatchTestKit.SMALL)
			_rows.add_thing(row * 100 + column, cell, small, BatchTestKit.SMALL_OFFSET)
	_batch = SpriteBatch.new()
	_batch.setup(_rows)
	# The scene that runs the tests holds the nodes. The root is still busy
	# adding that scene when the first test starts.
	tree.current_scene.add_child(_batch)
	_camera = Camera2D.new()
	_camera.position = Vector2(2000.0, 1000.0)
	_camera.zoom = Vector2(2.0, 2.0)
	tree.current_scene.add_child(_camera)
	_camera.make_current()
	_camera.force_update_scroll()


func after_each() -> void:
	_camera.free()
	_batch.free()


func test_art_is_drawn_with_crisp_pixels_on_the_opengl_renderer() -> void:
	var drawer := _batch.get_child(0) as MultiMeshInstance2D
	check_eq(drawer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	var filter_setting := "rendering/textures/canvas_textures/default_texture_filter"
	check_eq(ProjectSettings.get_setting(filter_setting), 0)
	check_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")
	check_eq(drawer.material, _batch.material())
	check_eq(_batch.material().shader, SpriteBatch.PLAIN_SHADER)


func test_the_whole_batch_is_one_mesh_with_one_image() -> void:
	check_eq(_batch.get_child_count(), 1)
	var drawer := _batch.get_child(0) as MultiMeshInstance2D
	check_eq(drawer.texture, _rows.atlas.texture())
	_batch.prepare_frame()
	check_eq(drawer.multimesh.instance_count, _batch.sprites_sent())


func test_the_view_follows_the_camera() -> void:
	var size := _batch.get_viewport_rect().size
	var view := _batch.view_rect()
	check_near(view.size.x, size.x / 2.0, 0.01)
	check_near(view.size.y, size.y / 2.0, 0.01)
	check_near(view.get_center().x, 2000.0, 0.01)
	check_near(view.get_center().y, 1000.0, 0.01)


func test_only_the_view_is_sent() -> void:
	_batch.prepare_frame()
	check(_batch.sprites_sent() > 0, "something is on screen")
	check(_batch.sprites_sent() < _rows.thing_count(), "the things off screen are left out")
	var buffer := PackedFloat32Array()
	check_eq(_batch.sprites_sent(), _rows.assemble(_batch.view_rect(), buffer))


func test_nothing_is_sent_again_while_nothing_changes() -> void:
	_batch.prepare_frame()
	check_eq(_batch.sends(), 1)
	_batch.prepare_frame()
	_batch.prepare_frame()
	check_eq(_batch.sends(), 1, "a still village with a still camera sends nothing new")
	_rows.tint_thing(1010, Color.RED)
	_batch.prepare_frame()
	check_eq(_batch.sends(), 2, "a change is sent")
	_camera.position.x += 100.0
	_camera.force_update_scroll()
	_batch.prepare_frame()
	check_eq(_batch.sends(), 3, "a camera move is sent")


func test_a_screen_position_finds_the_thing_under_it() -> void:
	var cell := Vector2i(20, 20)
	var world := _cells.position_of(cell) + BatchTestKit.SMALL_OFFSET * 10.0
	var screen := _batch.get_global_transform_with_canvas() * world
	check_eq(_batch.to_world(screen).round(), world)
	# The mouse hovering and the mouse clicking ask the same question.
	check_eq(_batch.thing_at_screen(screen), 2020)
	check_eq(_batch.thing_at_screen(screen), _rows.pick(world))
	var ground := _batch.get_global_transform_with_canvas() * Vector2(-900.0, -900.0)
	check_eq(_batch.thing_at_screen(ground), BatchRows.NO_THING)
