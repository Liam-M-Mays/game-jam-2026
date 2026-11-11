extends GameTest
## Checks the curve of each effect: what it is worth a given time after it started.

## The springy ease at its half way point: it is already past 1.
const BACK_AT_HALF := 1.0876975
## The sine ease at its half way point.
const SINE_AT_HALF := 0.70710678


func test_the_springy_ease_goes_past_one_and_settles_on_one() -> void:
	check_near(EffectCurves.back_out(0.0), 0.0, 0.000001)
	check_near(EffectCurves.back_out(0.5), BACK_AT_HALF, 0.000001)
	check_near(EffectCurves.back_out(1.0), 1.0, 0.000001)
	check_near(EffectCurves.back_out(2.0), 1.0, 0.000001, "it stays at 1 afterwards")
	var highest := 0.0
	for step in 101:
		highest = maxf(highest, EffectCurves.back_out(step / 100.0))
	check_near(highest, 1.1, 0.001, "the overshoot is 10 percent")


func test_the_sine_ease_is_fast_at_first() -> void:
	check_near(EffectCurves.sine_out(0.0), 0.0, 0.000001)
	check_near(EffectCurves.sine_out(0.5), SINE_AT_HALF, 0.000001)
	check_near(EffectCurves.sine_out(1.0), 1.0, 0.000001)


func test_a_flash_starts_full_and_fades_in_a_straight_line() -> void:
	check_eq(EffectCurves.flash_amount(0.0, 0.0, 2.0), 1.0)
	check_eq(EffectCurves.flash_amount(0.5, 0.0, 2.0), 0.75)
	check_eq(EffectCurves.flash_amount(1.0, 0.0, 2.0), 0.5)
	check_eq(EffectCurves.flash_amount(2.0, 0.0, 2.0), 0.0)
	check_eq(EffectCurves.flash_amount(9.0, 0.0, 2.0), 0.0)


func test_a_held_flash_stays_full_and_fades_afterwards() -> void:
	check_eq(EffectCurves.flash_amount(0.0, 1.0, 2.0), 1.0)
	check_eq(EffectCurves.flash_amount(1.0, 1.0, 2.0), 1.0)
	check_eq(EffectCurves.flash_amount(2.0, 1.0, 2.0), 0.5)
	check_eq(EffectCurves.flash_amount(3.0, 1.0, 2.0), 0.0)
	check_eq(EffectCurves.flash_amount(1.5, 1.0, 0.0), 0.0, "with no fade it is gone at once")


func test_a_shake_swings_out_across_half_out_half_across_and_back() -> void:
	var at_each_fifth: Array[float] = [0.0, 8.0, -8.0, 4.0, -4.0, 0.0]
	for fifth in 6:
		check_near(EffectCurves.shake_offset(fifth * 2.0, 10.0, 8.0), at_each_fifth[fifth], 0.000001)
	check_near(EffectCurves.shake_offset(1.0, 10.0, 8.0), 4.0, 0.000001, "half way out")
	check_near(EffectCurves.shake_offset(3.0, 10.0, 8.0), 0.0, 0.000001, "half way across")
	check_eq(EffectCurves.shake_offset(11.0, 10.0, 8.0), 0.0, "after the end")
	check_eq(EffectCurves.shake_offset(1.0, 0.0, 8.0), 0.0, "a shake of no time does nothing")


func test_a_squash_springs_from_its_start_size_back_to_full_size() -> void:
	var from := Vector2(1.5, 0.5)
	check_eq(EffectCurves.squash_scale(0.0, 4.0, from), from)
	var half := EffectCurves.squash_scale(2.0, 4.0, from)
	check_near(half.x, 1.5 - 0.5 * BACK_AT_HALF, 0.000001)
	check_near(half.y, 0.5 + 0.5 * BACK_AT_HALF, 0.000001)
	check(half.x < 1.0 and half.y > 1.0, "half way it is already past full size")
	check_eq(EffectCurves.squash_scale(4.0, 4.0, from), Vector2.ONE)
	check_eq(EffectCurves.squash_scale(1.0, 0.0, from), Vector2.ONE, "no time, no squash")


func test_a_wobble_rocks_one_way_then_the_other_and_back() -> void:
	check_near(EffectCurves.wobble_angle(0.0, 8.0, 0.5), 0.0, 0.000001)
	check_near(EffectCurves.wobble_angle(1.0, 8.0, 0.5), 0.25, 0.000001)
	check_near(EffectCurves.wobble_angle(2.0, 8.0, 0.5), 0.5, 0.000001, "a quarter in: full tilt")
	check_near(EffectCurves.wobble_angle(4.0, 8.0, 0.5), 0.0, 0.000001, "half way: upright")
	check_near(EffectCurves.wobble_angle(6.0, 8.0, 0.5), -0.5, 0.000001, "the other side")
	check_near(EffectCurves.wobble_angle(7.0, 8.0, 0.5), -0.25, 0.000001)
	check_eq(EffectCurves.wobble_angle(8.0, 8.0, 0.5), 0.0)


func test_a_wobble_and_a_pop_can_start_from_where_the_sprite_is() -> void:
	# A wobble that starts at a tilt of 0.25 goes on to 0.5 in a straight line.
	check_near(EffectCurves.wobble_angle(0.0, 8.0, 0.5, 0.25), 0.25, 0.000001)
	check_near(EffectCurves.wobble_angle(1.0, 8.0, 0.5, 0.25), 0.375, 0.000001)
	check_near(EffectCurves.wobble_angle(2.0, 8.0, 0.5, 0.25), 0.5, 0.000001, "full tilt")
	check_near(EffectCurves.wobble_angle(4.0, 8.0, 0.5, 0.25), 0.0, 0.000001, "then as always")
	# A pop that starts at 1.25 eases on to 1.5 and comes back as always.
	check_near(EffectCurves.pop_scale(0.0, 0.5, 2.0, 6.0, 1.25), 1.25, 0.000001)
	check_near(
		EffectCurves.pop_scale(1.0, 0.5, 2.0, 6.0, 1.25), 1.25 + 0.25 * SINE_AT_HALF, 0.000001
	)
	check_near(EffectCurves.pop_scale(2.0, 0.5, 2.0, 6.0, 1.25), 1.5, 0.000001, "the top")
	check_near(
		EffectCurves.pop_scale(5.0, 0.5, 2.0, 6.0, 1.25), 1.5 - 0.5 * SINE_AT_HALF, 0.000001
	)


func test_a_pop_gets_bigger_fast_and_comes_back() -> void:
	check_near(EffectCurves.pop_scale(0.0, 0.5, 2.0, 6.0), 1.0, 0.000001)
	check_near(EffectCurves.pop_scale(1.0, 0.5, 2.0, 6.0), 1.0 + 0.5 * SINE_AT_HALF, 0.000001)
	check_near(EffectCurves.pop_scale(2.0, 0.5, 2.0, 6.0), 1.5, 0.000001, "the top")
	check_near(EffectCurves.pop_scale(5.0, 0.5, 2.0, 6.0), 1.5 - 0.5 * SINE_AT_HALF, 0.000001)
	check_eq(EffectCurves.pop_scale(8.0, 0.5, 2.0, 6.0), 1.0)
