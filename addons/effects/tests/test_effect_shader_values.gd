extends GameTest
## Checks what the effect shader is sent: the clock, the looks of the style,
## the table and how the batch node is turned and sized.
##
## A run with no window draws nothing, but it does compile a shader that is
## put on a material. So this is also the one place where the ready-made
## batch shader of the toolkit is compiled in CI. What the shader draws from
## these values is proven by the comparison pictures, in a window.

var _rows: BatchRows
var _batch: SpriteBatch
var _effects: SpriteEffects
var _style: EffectStyle


func before_each() -> void:
	_rows = EffectsTestKit.rows()
	_rows.add_thing(1, Vector2i(2, 3), _rows.atlas.find(BatchTestKit.TALL))
	_style = EffectsTestKit.style()
	_style.select_colour = Color(0.1, 0.2, 0.3, 0.4)
	_style.select_width = 3.0
	_style.select_glow_size = 4.0
	_style.select_glow_strength = 0.25
	_style.select_pulse_speed = 2.0
	_style.select_pulse_amount = 0.125
	_style.hover_colour = Color(0.5, 0.6, 0.7, 0.8)
	_style.hover_width = 1.0
	_style.hover_glow_size = 5.0
	_style.hover_glow_strength = 0.5
	_style.hover_pulse_speed = 0.3
	_style.hover_pulse_amount = 0.75
	_style.ghost_dark = 0.5
	_style.ghost_light = 1.5
	_batch = SpriteBatch.new()
	_batch.setup(_rows, SpriteEffects.SHADER)
	tree.current_scene.add_child(_batch)
	_effects = SpriteEffects.new(_rows, _style)
	_effects.dress(_batch)


func after_each() -> void:
	_effects.close()
	_batch.free()


func test_the_ready_made_effect_shader_compiles_with_every_value_it_is_sent() -> void:
	check_eq(_batch.material().shader, SpriteEffects.SHADER)
	var known := PackedStringArray()
	for uniform: Dictionary in SpriteEffects.SHADER.get_shader_uniform_list():
		known.append(uniform["name"])
	for wanted: String in [
		"effects_table", "effects_clock", "effects_clock_wrap", "effects_select_width",
		"effects_hover_glow_size", "effects_ghost_dark", "batch_atlas", "batch_turn_inverse",
		"batch_clock",
	]:
		check(known.has(wanted), "the shader has the value %s" % wanted)


func test_the_shader_clock_runs_on_game_time() -> void:
	# 100.5 seconds at x3 are 301.5 seconds of game time. The clock starts
	# again at 256, so the shader is sent 45.5.
	_effects.advance(100.5, 3.0)
	RenderingServer.frame_pre_draw.emit()
	check_eq(_sent(&"effects_clock"), 45.5, "x3, wrapped to the clock")
	check_eq(_sent(&"effects_clock_wrap"), SpriteEffects.CLOCK_WRAP)
	_effects.advance(10.0, 3.0, true)
	RenderingServer.frame_pre_draw.emit()
	check_eq(_sent(&"effects_clock"), 45.5, "it stands still while the game is paused")
	_effects.advance(1.0, 1.5)
	RenderingServer.frame_pre_draw.emit()
	check_eq(_sent(&"effects_clock"), 47.0, "and runs on at the new speed")


func test_the_shader_gets_the_looks_of_the_style() -> void:
	check_eq(_sent(&"effects_select_colour"), Color(0.1, 0.2, 0.3, 0.4))
	check_eq(_sent(&"effects_select_width"), 3.0)
	check_eq(_sent(&"effects_select_glow_size"), 4.0)
	check_eq(_sent(&"effects_select_glow_strength"), 0.25)
	check_eq(_sent(&"effects_select_pulse_amount"), 0.125)
	check_eq(_sent(&"effects_hover_colour"), Color(0.5, 0.6, 0.7, 0.8))
	check_eq(_sent(&"effects_hover_width"), 1.0)
	check_eq(_sent(&"effects_hover_glow_size"), 5.0)
	check_eq(_sent(&"effects_hover_glow_strength"), 0.5)
	check_eq(_sent(&"effects_hover_pulse_amount"), 0.75)
	check_eq(_sent(&"effects_ghost_dark"), 0.5)
	check_eq(_sent(&"effects_ghost_light"), 1.5)
	# A changed style is sent when the batch is dressed again.
	_style.hover_width = 6.0
	_effects.dress(_batch)
	check_eq(_sent(&"effects_hover_width"), 6.0)


func test_a_pulse_fits_a_whole_number_of_times_into_the_clock() -> void:
	# Or the outline would jump when the clock starts again.
	check_eq(_sent(&"effects_select_pulse_speed"), 2.0, "512 pulses fit already")
	var hover: float = _sent(&"effects_hover_pulse_speed")
	check_eq(hover, 77.0 / 256.0, "0.3 a second is 76.8 pulses: made 77")
	check(hover != 0.0)
	check_eq(fmod(hover * SpriteEffects.CLOCK_WRAP, 1.0), 0.0)


func test_the_shader_gets_the_effect_table_and_the_atlas() -> void:
	check_eq(_sent(&"effects_table"), _effects.table().texture())
	check_eq(_sent(&"batch_atlas"), _rows.atlas.texture())
	# The table grows: the shader must get the new texture.
	for id in range(2, 2 + EffectTable.START_LINES):
		_rows.add_thing(id, Vector2i(id, 0), _rows.atlas.find(BatchTestKit.SMALL))
		_effects.flash(SpriteEffects.thing(id))
	RenderingServer.frame_pre_draw.emit()
	check_eq(_effects.table().line_count(), EffectTable.START_LINES * 2)
	check_eq(_sent(&"effects_table"), _effects.table().texture())


func test_the_shader_is_told_how_the_batch_node_is_turned_and_sized() -> void:
	# The shader needs it to read the effect number of a sprite.
	_batch.prepare_frame()
	check_eq(_sent(&"batch_turn_inverse"), Transform2D.IDENTITY)
	_batch.scale = Vector2(2.0, 4.0)
	_batch.position = Vector2(300.0, -200.0)
	_batch.prepare_frame()
	var undo: Transform2D = _sent(&"batch_turn_inverse")
	check_eq(undo.x, Vector2(0.5, 0.0), "twice as wide: halved")
	check_eq(undo.y, Vector2(0.0, 0.25))
	check_eq(undo.origin, Vector2.ZERO, "where the node is does not matter")
	_batch.scale = Vector2.ONE
	_batch.rotation = PI * 0.5
	_batch.prepare_frame()
	undo = _sent(&"batch_turn_inverse")
	check(undo.x.is_equal_approx(Vector2(0.0, -1.0)), "a quarter turn is turned back")
	check(undo.y.is_equal_approx(Vector2(1.0, 0.0)))


func _sent(uniform: StringName) -> Variant:
	return _batch.material().get_shader_parameter(uniform)
