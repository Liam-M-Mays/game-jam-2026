class_name MeepleTopple
extends Object
## How a dying meeple tips over and fades: the jam game's tween, as maths.
##
## The jam game ran a tween on each dying meeple. Here the same curve is a
## function of the time since the meeple died. [VillageMeeples] asks it once a
## tick and stores the answers, and the meeple shader draws them.
## The numbers are in [MeepleNumbers].

## The angle of a meeple that lies flat, in radians.
const LYING := PI * 0.5


## How far a meeple has tipped over [param seconds] after it died, in radians,
## from 0 (upright) to [constant LYING]. It falls faster and faster, bounces
## back once and comes down again. Which side it falls to is the caller's.
static func angle_at(seconds: float) -> float:
	if seconds <= 0.0:
		return 0.0
	var fall := MeepleNumbers.FALL_SECONDS
	var bounce := MeepleNumbers.REBOUND_SECONDS
	if seconds <= fall:
		var share := seconds / fall
		return LYING * share * share
	if seconds <= fall + bounce:
		var up := (seconds - fall) / bounce
		return LYING - MeepleNumbers.REBOUND * sin(up * PI * 0.5)
	if seconds <= fall + bounce * 2.0:
		var down := (seconds - fall - bounce) / bounce
		return LYING - MeepleNumbers.REBOUND * cos(down * PI * 0.5)
	return LYING


## How solid a meeple is [param seconds] after it died: 1 until it has lain
## still for a moment, then down to 0 in a straight line.
static func fade_at(seconds: float) -> float:
	var fade_start := fade_starts_at()
	if seconds <= fade_start:
		return 1.0
	return clampf(1.0 - (seconds - fade_start) / MeepleNumbers.FADE_SECONDS, 0.0, 1.0)


## How many seconds after its death a meeple starts to fade.
static func fade_starts_at() -> float:
	return (
		MeepleNumbers.FALL_SECONDS
		+ MeepleNumbers.REBOUND_SECONDS * 2.0
		+ MeepleNumbers.LIE_SECONDS
	)


## True once a meeple that died [param seconds] ago has faded away. It is
## taken out of the village then.
static func is_over(seconds: float) -> bool:
	return seconds >= fade_starts_at() + MeepleNumbers.FADE_SECONDS
