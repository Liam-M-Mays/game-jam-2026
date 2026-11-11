class_name EffectsTestKit
extends RefCounted
## Helpers the effects tests share: sample effect numbers and a small batch.
##
## The numbers here are sample values for the tests. They are not the game's
## numbers, and the toolkit does not use them. The times are whole steps of
## [constant STEP], so a test can count frames with no rounding.

## The length of one test frame, in seconds. It is exact in binary.
const STEP := 1.0 / 128.0
## The sample colours.
const REJECT := Color(0.25, 0.5, 0.75)
const GHOST := Color(0.125, 0.25, 0.5)
const BLOCKED := Color(0.75, 0.25, 0.125)


## Returns sample effect numbers.
static func style() -> EffectStyle:
	var sample := EffectStyle.new()
	sample.flash_seconds = 0.75
	sample.reject_colour = REJECT
	sample.shake_seconds = 0.375
	sample.shake_distance = 4.0
	sample.squash_amount = 0.5
	sample.squash_seconds = 0.75
	sample.grow_from = Vector2(0.5, 0.25)
	sample.grow_seconds = 1.5
	sample.wobble_degrees = 10.0
	sample.wobble_seconds = 0.375
	sample.pop_amount = 0.25
	sample.pop_rise_seconds = 0.1875
	sample.pop_fall_seconds = 0.5625
	sample.select_width = 3.0
	sample.hover_glow_size = 5.0
	sample.hover_glow_strength = 0.5
	sample.ghost_colour = GHOST
	sample.ghost_blocked_colour = BLOCKED
	sample.ghost_opacity = 0.75
	sample.ghost_under_opacity = 0.25
	sample.ghost_dark = 0.5
	sample.ghost_light = 1.5
	return sample


## Returns empty batch rows on the grid of the sprite batch tests.
static func rows() -> BatchRows:
	var world := Rect2(-4000.0, -4000.0, 8000.0, 8000.0)
	var made := BatchRows.new(
		BatchTestKit.cells(), BatchTestKit.atlas(), world, BatchTestKit.ART_SCALE
	)
	made.shape_movers(Vector2(30.0, 60.0), Vector2(0.0, -20.0))
	return made
