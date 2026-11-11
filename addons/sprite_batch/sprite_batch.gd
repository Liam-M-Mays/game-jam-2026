class_name SpriteBatch
extends Node2D
## Draws everything in a [BatchRows] as one batch: one mesh, one image, one draw call.
##
## Fill a [BatchRows], hand it to [method setup] and add this node to the scene.
## Just before each frame is drawn it asks the rows for what is on screen and
## sends that to the graphics card. It sends nothing in a frame where the rows
## did not change and the view did not move. While movers move, it sends the
## sprites on screen again every frame.

## The shader used when [method setup] is given none.
const PLAIN_SHADER := preload("res://addons/sprite_batch/sprite_batch.gdshader")
## The clock starts again after this many seconds, so it stays exact.
const CLOCK_WRAP := 3600.0

## The sprites this node draws.
var rows: BatchRows
## The clock the shader reads, in seconds. It runs by itself. The shader gets
## it wrapped to [member clock_wrap], so it stays exact however late it is.
var clock: float = 0.0
## Set this to stop the clock, for a still picture.
var clock_frozen: bool = false
## The clock starts again at 0 when it reaches this many seconds.
var clock_wrap: float = CLOCK_WRAP

var _multimesh: MultiMesh
var _material: ShaderMaterial
var _buffer := PackedFloat32Array()
var _sent := 0
var _sends := 0
var _seen_serial := -1
var _seen_view := Rect2()
var _seen_turn := Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
var _prepare_usec := 0


func _enter_tree() -> void:
	RenderingServer.frame_pre_draw.connect(prepare_frame)


func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(prepare_frame)


func _process(delta: float) -> void:
	if not clock_frozen:
		clock = fmod(clock + delta, clock_wrap)


## Starts drawing [param batch_rows]. [param shader] must include
## [code]sprite_batch.gdshaderinc[/code]. Leave it out for plain sprites.
func setup(batch_rows: BatchRows, shader: Shader = null) -> void:
	rows = batch_rows
	_seen_turn = Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	_material = ShaderMaterial.new()
	_material.shader = shader if shader != null else PLAIN_SHADER
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = _unit_quad()
	# The batch leaves out what is off screen itself, so Godot is told the mesh
	# is everywhere. Without this Godot measures every sprite again each frame.
	_multimesh.custom_aabb = AABB(Vector3(-1e7, -1e7, -1.0), Vector3(2e7, 2e7, 2.0))
	var drawer := MultiMeshInstance2D.new()
	drawer.multimesh = _multimesh
	drawer.material = _material
	drawer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(drawer)
	refresh_atlas()


## Call this after the atlas was built again, so the batch draws the new image.
func refresh_atlas() -> void:
	var drawer := get_child(0) as MultiMeshInstance2D
	drawer.texture = rows.atlas.texture()
	_material.set_shader_parameter(&"batch_atlas", rows.atlas.texture())
	_material.set_shader_parameter(&"batch_rects", rows.atlas.rects_texture())
	_material.set_shader_parameter(&"batch_atlas_size", Vector2(rows.atlas.image().get_size()))
	_seen_serial = -1


## Returns the material, so a game shader can be given its own values.
func material() -> ShaderMaterial:
	return _material


## Returns the part of the world this node's viewport shows, in this node's own pixels.
func view_rect() -> Rect2:
	return get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()


## Returns how many sprites were sent to the graphics card for the last frame.
func sprites_sent() -> int:
	return _sent


## Returns how many times a new buffer was sent to the graphics card. It
## stands still while the rows do not change and the view does not move.
func sends() -> int:
	return _sends


## Returns how long the last frame's assembling and sending took, in microseconds.
func prepare_usec() -> int:
	return _prepare_usec


## Returns the thing under the screen position [param screen_point], or
## [constant BatchRows.NO_THING]. See [method BatchRows.pick].
func thing_at_screen(screen_point: Vector2) -> int:
	return rows.pick(to_world(screen_point))


## Turns a screen position into a position in this node's own pixels.
func to_world(screen_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_point


## Gets the batch ready for the frame that is about to be drawn. It runs by
## itself just before every frame. When the rows or the view changed, it asks
## the rows for what is on screen and sends that to the graphics card.
func prepare_frame() -> void:
	if rows == null or not is_visible_in_tree():
		return
	var started := Time.get_ticks_usec()
	_material.set_shader_parameter(&"batch_clock", fmod(clock, clock_wrap))
	_send_turn()
	var view := view_rect()
	if rows.serial() != _seen_serial or view != _seen_view:
		_seen_serial = rows.serial()
		_seen_view = view
		_sent = rows.assemble(view, _buffer)
		if _multimesh.instance_count != _sent:
			_multimesh.instance_count = _sent
		if _sent > 0:
			RenderingServer.multimesh_set_buffer(_multimesh.get_rid(), _buffer)
		_sends += 1
	_prepare_usec = Time.get_ticks_usec() - started


## Tells the shader how this node is turned and sized, so that it can read
## the extra number of a sprite. See batch_extra in sprite_batch.gdshaderinc.
func _send_turn() -> void:
	var here := get_global_transform()
	var turn := Transform2D(here.x, here.y, Vector2.ZERO)
	if turn == _seen_turn:
		return
	_seen_turn = turn
	var undo := Transform2D.IDENTITY
	if not is_zero_approx(turn.determinant()):
		undo = turn.affine_inverse()
	_material.set_shader_parameter(&"batch_turn_inverse", undo)


func _unit_quad() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var quad := ArrayMesh.new()
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return quad
