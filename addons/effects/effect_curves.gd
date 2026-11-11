class_name EffectCurves
extends RefCounted
## The curve of each effect: what it is worth a given time after it started.
##
## The shader works the same curves out for every sprite on screen, in
## [code]effects.gdshaderinc[/code]. This copy is here so that code with no
## window, such as a test, can ask what an effect is doing.
## [param age] is always the game time since the effect started, in seconds.

## The overshoot of [method back_out]. It is the number Godot's own tweens use.
const BACK_OVERSHOOT := 1.70158
## Where a shake is after each fifth of its time, against its distance.
const SHAKE_KEYS: Array[float] = [0.0, 1.0, -1.0, 0.5, -0.5, 0.0]


## Eases from 0 to 1, going a bit past 1 before it settles. [param t] is 0 to 1.
static func back_out(t: float) -> float:
	var back := clampf(t, 0.0, 1.0) - 1.0
	return back * back * ((BACK_OVERSHOOT + 1.0) * back + BACK_OVERSHOOT) + 1.0


## Eases from 0 to 1, fast at first. [param t] is 0 to 1.
static func sine_out(t: float) -> float:
	return sin(clampf(t, 0.0, 1.0) * PI * 0.5)


## How much of the flash colour is mixed in, 1 to 0. The flash stays full for
## [param hold] seconds and then fades in a straight line over [param fade].
static func flash_amount(age: float, hold: float, fade: float) -> float:
	if age <= hold:
		return 1.0
	if fade <= 0.0:
		return 0.0
	return clampf(1.0 - (age - hold) / fade, 0.0, 1.0)


## How far a shake has moved the picture sideways. It swings out, across,
## half out, half across and back, in five equal steps.
static func shake_offset(age: float, seconds: float, distance: float) -> float:
	if seconds <= 0.0 or age >= seconds or age < 0.0:
		return 0.0
	var step := age / seconds * 5.0
	var index := mini(int(step), 4)
	return lerpf(SHAKE_KEYS[index], SHAKE_KEYS[index + 1], step - index) * distance


## The size of a squashed picture against its full size. It starts at
## [param from] and springs back to full size with a small overshoot.
static func squash_scale(age: float, seconds: float, from: Vector2) -> Vector2:
	if seconds <= 0.0 or age >= seconds:
		return Vector2.ONE
	return from + (Vector2.ONE - from) * back_out(age / seconds)


## The tilt of a wobble: to [param angle] in the first quarter, across to the
## other side in the next half, and back to upright in the last quarter.
## [param from] is the tilt it starts at: not 0 when it took over from a
## wobble that was still running.
static func wobble_angle(age: float, seconds: float, angle: float, from: float = 0.0) -> float:
	if seconds <= 0.0 or age >= seconds or age < 0.0:
		return 0.0
	var t := age / seconds
	if t < 0.25:
		return lerpf(from, angle, t * 4.0)
	if t < 0.75:
		return angle * (1.0 - (t - 0.25) * 4.0)
	return -angle * (1.0 - (t - 0.75) * 4.0)


## The size of a popping picture against its full size: up by [param amount]
## in [param rise] seconds, and back in [param fall] seconds. [param from] is
## the size it starts at: not 1 when it took over from a pop that was still
## running.
static func pop_scale(
		age: float, amount: float, rise: float, fall: float, from: float = 1.0
) -> float:
	if age < 0.0 or age >= rise + fall:
		return 1.0
	if age < rise:
		return lerpf(from, 1.0 + amount, sine_out(age / rise))
	return 1.0 + amount * (1.0 - sine_out((age - rise) / fall))
