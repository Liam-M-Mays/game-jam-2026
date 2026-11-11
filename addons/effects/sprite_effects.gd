class_name SpriteEffects
extends EffectLines
## The effects toolkit: one place for the outline and the effects of a sprite batch.
##
## Every sprite is called the same way, a tree, a building or a meeple. Get
## its target number with [method thing] or [method mover], then call the
## effect: [method flash], [method reject], [method squash], [method wobble],
## [method pop], [method grow_in], [method hover], [method select],
## [method ghost], [method ghost_under]. No game script needs a tween.
##
## Inside the batch an effect is a value per sprite that the shader reads.
## A sprite with an effect carries an effect number (its extra number in
## [BatchRows]). The number is a line of the [EffectTable], and the shader
## works the effect out from that line and from the effect clock. Which
## sprite reads which line is kept by [EffectLines], which this class extends.
##
## One-shot sprites such as a spark or a dust cloud are played by
## [member shots]. Lit cells are a class of their own, [CellHighlights].
##
## Effects run on game time. Call [method advance] once a frame with the
## game speed and the pause. At x3 an effect takes a third of the time, and
## nothing moves while the game is paused.
##
## Nothing here needs a window, so all of it can be tested alone.

## A batch shader for plain sprites with effects. A game with its own batch
## shader includes [code]effects.gdshaderinc[/code] instead.
const SHADER := preload("res://addons/effects/effects_batch.gdshader")

## The numbers of the effects. The game hands them in.
var style: EffectStyle:
	get:
		return _style
## The sprites the effects are shown on.
var rows: BatchRows:
	get:
		return _rows

## The one-shot sprites, such as a spark or a dust cloud. They play on the
## same game time as the effects.
var shots: EffectShots

var _material: ShaderMaterial
var _sent_table: ImageTexture


## [param batch_rows] holds the sprites. [param effect_style] holds the
## numbers of the game.
func _init(batch_rows: BatchRows, effect_style: EffectStyle) -> void:
	_rows = batch_rows
	_style = effect_style
	shots = EffectShots.new(batch_rows)


## Returns the target number of the thing [param id] of the batch.
static func thing(id: int) -> int:
	return id * 2


## Returns the target number of mover [param index] of the batch.
static func mover(index: int) -> int:
	return index * 2 + 1


## Gives [param batch] what the effect shader needs, and keeps it up to date
## before every frame. The batch must have been set up with [constant SHADER]
## or with a shader that includes [code]effects.gdshaderinc[/code].
## Call it again after a value of [member style] was changed.
func dress(batch: SpriteBatch) -> void:
	_material = batch.material()
	_sent_table = null
	var values := {
		&"effects_clock_wrap": CLOCK_WRAP,
		&"effects_select_colour": _style.select_colour,
		&"effects_select_width": _style.select_width,
		&"effects_select_glow_size": _style.select_glow_size,
		&"effects_select_glow_strength": _style.select_glow_strength,
		&"effects_select_pulse_speed": _whole_pulses(_style.select_pulse_speed),
		&"effects_select_pulse_amount": _style.select_pulse_amount,
		&"effects_hover_colour": _style.hover_colour,
		&"effects_hover_width": _style.hover_width,
		&"effects_hover_glow_size": _style.hover_glow_size,
		&"effects_hover_glow_strength": _style.hover_glow_strength,
		&"effects_hover_pulse_speed": _whole_pulses(_style.hover_pulse_speed),
		&"effects_hover_pulse_amount": _style.hover_pulse_amount,
		&"effects_ghost_dark": _style.ghost_dark,
		&"effects_ghost_light": _style.ghost_light,
	}
	for uniform: StringName in values:
		_material.set_shader_parameter(uniform, values[uniform])
	_prepare_frame()
	if not RenderingServer.frame_pre_draw.is_connected(_prepare_frame):
		RenderingServer.frame_pre_draw.connect(_prepare_frame)


## Lets go of the batch and of every effect. Call it when the view closes.
func close() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_prepare_frame):
		RenderingServer.frame_pre_draw.disconnect(_prepare_frame)
	for target: int in _states.keys():
		forget(target)
	shots.stop_all()
	_material = null
	_sent_table = null


## Moves the effects on by [param real_seconds] of a frame. [param speed] is
## the game speed and [param paused] the pause of the game. Effects run on
## game time: at speed 3 they take a third of the time, and while paused
## nothing moves.
func advance(real_seconds: float, speed: float = 1.0, paused: bool = false) -> void:
	if not (paused or real_seconds <= 0.0 or speed <= 0.0):
		_now += real_seconds * speed
		if _now >= _next_end:
			_end_finished()
		shots.advance_to(_now)
	_serve_waiting()


## Shows or hides the hover outline of [param target].
func hover(target: int, on: bool) -> void:
	var state := _state(target, on)
	if state == null or (state.hovered == on and not _waiting.has(target)):
		return
	state.hovered = on
	_refresh(target, state)


## Shows or hides the selected outline of [param target]. [param tint]
## colours the outline.
func select(target: int, on: bool, tint: Color = Color.WHITE) -> void:
	var state := _state(target, on)
	var same := state != null and state.selected == on and (not on or state.select_tint == tint)
	if state == null or (same and not _waiting.has(target)):
		return
	state.selected = on
	state.select_tint = tint if on else Color.WHITE
	_refresh(target, state)


## Draws [param target] as a blueprint ghost, or as itself again. A ghost
## that is [param blocked] takes the blocked colour.
func ghost(target: int, on: bool, blocked: bool = false) -> void:
	var state := _state(target, on)
	if state == null:
		return
	state.ghost = _style.ghost_opacity if on else 0.0
	_tint_ghosts(state, on, blocked)
	_refresh(target, state)


## Draws [param sprite] as a ghost behind [param target]. Use it for the
## next stage of a building site. Both pictures must be the same size. The
## outline wraps the two as one shape. Pass [constant SpriteAtlas.NO_SPRITE]
## to take the ghost away.
func ghost_under(target: int, sprite: int, blocked: bool = false) -> void:
	var on := sprite != SpriteAtlas.NO_SPRITE
	var state := _state(target, on)
	if state == null:
		return
	state.under_sprite = sprite if on else -1
	state.under = _style.ghost_under_opacity if on else 0.0
	_tint_ghosts(state, on, blocked)
	_refresh(target, state)


## Turns [param target] one solid colour, which fades back to normal. With
## [param hold] it stays solid for that many seconds first.
func flash(target: int, colour: Color = Color.WHITE, hold: float = 0.0) -> void:
	var held := clampf(hold, 0.0, CLOCK_WRAP * 0.25)
	var state := _timed_state(target, held + _style.flash_seconds)
	if state == null:
		return
	state.flash_colour = colour
	state.flash_hold = held
	state.flash_fade = _style.flash_seconds
	state.start(EffectState.FLASH, _now, state.flash_hold + state.flash_fade)
	_refresh(target, state)


## Shakes [param target] left and right.
func shake(target: int) -> void:
	var state := _timed_state(target, _style.shake_seconds)
	if state == null:
		return
	state.shake_seconds = _style.shake_seconds
	state.shake_distance = _style.shake_distance
	state.start(EffectState.SHAKE, _now, state.shake_seconds)
	_refresh(target, state)


## The answer to a refused action: a flash in the reject colour and a shake.
func reject(target: int) -> void:
	flash(target, _style.reject_colour)
	shake(target)


## Squashes [param target] wider and shorter, and lets it spring back.
## [param amount] is how much: leave it out for the amount of the style.
func squash(target: int, amount: float = NAN) -> void:
	var by := _style.squash_amount if is_nan(amount) else amount
	_start_squash(target, Vector2(1.0 + by, 1.0 - by), _style.squash_seconds)


## Lets [param target] pop up from a flat sliver to its full size.
func grow_in(target: int) -> void:
	_start_squash(target, _style.grow_from, _style.grow_seconds)


## Rocks [param target] to one side, to the other and back. [param degrees]
## is how far: leave it out for the angle of the style. A wobble that takes
## over from a running one carries on from the tilt the sprite has.
func wobble(target: int, degrees: float = NAN) -> void:
	var state := _timed_state(target, _style.wobble_seconds)
	if state == null:
		return
	state.wobble_from = _wobble_now(state)
	state.wobble_radians = deg_to_rad(_style.wobble_degrees if is_nan(degrees) else degrees)
	state.wobble_seconds = _style.wobble_seconds
	state.start(EffectState.WOBBLE, _now, state.wobble_seconds)
	_refresh(target, state)


## Gives [param target] a quick little bounce. [param amount] is how much
## bigger it gets: leave it out for the amount of the style. A pop that takes
## over from a running one carries on from the size the sprite has, so many
## pops in a row do not snap back.
func pop(target: int, amount: float = NAN) -> void:
	var state := _timed_state(target, _style.pop_rise_seconds + _style.pop_fall_seconds)
	if state == null:
		return
	state.pop_from = _pop_now(state)
	state.pop_amount = _style.pop_amount if is_nan(amount) else amount
	state.pop_rise = _style.pop_rise_seconds
	state.pop_fall = _style.pop_fall_seconds
	state.start(EffectState.POP, _now, state.pop_rise + state.pop_fall)
	_refresh(target, state)


## Returns what the timed effects of [param target] are doing right now:
## [code]flash[/code] is how much of [code]flash_colour[/code] is mixed in,
## [code]shift[/code] is the sideways shake in art pixels, [code]scale[/code]
## is its size against full size, and [code]degrees[/code] is its tilt.
## The shader works the same numbers out. This copy is for code with no window.
func pose(target: int) -> Dictionary:
	var result := {
		"flash": 0.0, "flash_colour": Color.WHITE, "shift": 0.0,
		"scale": Vector2.ONE, "degrees": 0.0,
	}
	var state: EffectState = _states.get(target)
	if state == null:
		return result
	var starts := state.starts
	if starts[EffectState.FLASH] != EffectState.OFF:
		var age := _now - starts[EffectState.FLASH]
		result["flash"] = EffectCurves.flash_amount(age, state.flash_hold, state.flash_fade)
		result["flash_colour"] = state.flash_colour
	if starts[EffectState.SHAKE] != EffectState.OFF:
		result["shift"] = EffectCurves.shake_offset(
			_now - starts[EffectState.SHAKE], state.shake_seconds, state.shake_distance
		)
	var scale := Vector2.ONE
	if starts[EffectState.SQUASH] != EffectState.OFF:
		scale = EffectCurves.squash_scale(
			_now - starts[EffectState.SQUASH], state.squash_seconds, state.squash_from
		)
	result["scale"] = scale * _pop_now(state)
	result["degrees"] = rad_to_deg(_wobble_now(state))
	return result


## The size the pop of a state gives it right now, against full size.
func _pop_now(state: EffectState) -> float:
	var start := state.starts[EffectState.POP]
	if start == EffectState.OFF:
		return 1.0
	return EffectCurves.pop_scale(
		_now - start, state.pop_amount, state.pop_rise, state.pop_fall, state.pop_from
	)


## The tilt the wobble of a state gives it right now, in radians.
func _wobble_now(state: EffectState) -> float:
	var start := state.starts[EffectState.WOBBLE]
	if start == EffectState.OFF:
		return 0.0
	return EffectCurves.wobble_angle(
		_now - start, state.wobble_seconds, state.wobble_radians, state.wobble_from
	)


## The state of a target for a timed effect of [param seconds]. Returns null
## when the effect takes no time, as in a style where it is switched off.
func _timed_state(target: int, seconds: float) -> EffectState:
	return _state(target, true) if seconds > 0.0 else null


func _start_squash(target: int, from: Vector2, seconds: float) -> void:
	var state := _timed_state(target, seconds)
	if state == null:
		return
	state.squash_from = from
	state.squash_seconds = seconds
	state.start(EffectState.SQUASH, _now, seconds)
	_refresh(target, state)


func _tint_ghosts(state: EffectState, on: bool, blocked: bool) -> void:
	if on:
		state.ghost_tint = _style.ghost_blocked_colour if blocked else _style.ghost_colour
	elif state.ghost <= 0.0 and state.under_sprite < 0:
		state.ghost_tint = Color.WHITE


## A pulse must fit a whole number of times into the clock, or it would jump
## when the clock starts again.
func _whole_pulses(speed: float) -> float:
	return roundf(speed * CLOCK_WRAP) / CLOCK_WRAP


## Gets the shader ready for the frame that is about to be drawn: the clock,
## and the table when a line changed. It runs by itself before every frame
## once [method dress] was called.
func _prepare_frame() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"effects_clock", fmod(_now, CLOCK_WRAP))
	if _table.is_dirty() or _sent_table == null:
		var table := _table.texture()
		if table != _sent_table:
			_sent_table = table
			_material.set_shader_parameter(&"effects_table", table)
