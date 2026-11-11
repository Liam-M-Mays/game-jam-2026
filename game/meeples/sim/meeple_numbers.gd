class_name MeepleNumbers
extends Object
## The jam game's meeple numbers, in one place.
##
## Every number is from [code]assets/Scripts/Meeple/meeple_movement.gd[/code].
## The jam game measured a walk in its own units: ten units are one art pixel.
## A village works in art pixels, as [GridLayout] does, so each distance here
## is turned into art pixels once, with [constant UNIT]. The jam number is the
## one written in front of it.
##
## One distance is the exception: [constant HOP_REACH]. The jam game measured
## it on the screen side of its scale, where one unit is one art pixel already.

## One jam unit in art pixels.
const UNIT := 0.1

## How fast a meeple walks on a job, in art pixels a second. 100 jam units.
const JOB_SPEED := 100.0 * UNIT
## How fast a meeple strolls when it wanders, in art pixels a second. 30 jam units.
const WANDER_SPEED := 30.0 * UNIT
## A meeple aims this far below the point it is sent to, so it is drawn in
## front of the thing there. 3 jam units down.
const AIM_BELOW := Vector2(0.0, 3.0) * UNIT
## A meeple this close to its target has arrived. 1 jam unit.
const ARRIVE := 1.0 * UNIT

## The shortest pause between two strolls, in seconds.
const PAUSE_MIN := 1.0
## The longest pause between two strolls, in seconds.
const PAUSE_MAX := 3.5
## How far from the spot where it went idle a meeple strolls at most, when it
## has no hangout. 60 jam units.
const WANDER_RADIUS := 60.0 * UNIT
## The shortest such stroll, as a share of [constant WANDER_RADIUS]. 15 jam units.
const WANDER_NEAREST := 0.25
## A stroll near a hangout goes to an empty cell at most this many steps from it.
const WANDER_RING := 2
## How many spots a meeple tries for one stroll.
const WANDER_TRIES := 8
## A spot near a hangout is nudged by up to this much each way, so meeples do
## not line up. 12 jam units sideways and 6 up and down.
const WANDER_JITTER := Vector2(12.0, 6.0) * UNIT
## At how many points the way to a spot is checked for a hangout in the way.
const PATH_CHECKS := 8
## The chance, on each stroll, that a meeple picks a hangout again.
const HOP_CHANCE := 0.15
## A hangout this far away is half as likely to be picked as one right here,
## in art pixels. The jam game divides this one distance by 100 after it took
## it from [code]global_position[/code], where one unit is one art pixel. So
## the 100 is in art pixels (1,000 jam units), and it is not turned with
## [constant UNIT].
const HOP_REACH := 100.0

## How long a dying meeple takes to tip over to 90 degrees, in seconds.
const FALL_SECONDS := 0.45
## How far it bounces back up after landing, in radians.
const REBOUND := 0.2
## How long the bounce takes each way, in seconds.
const REBOUND_SECONDS := 0.08
## How long it lies still, in seconds.
const LIE_SECONDS := 0.6
## How long it takes to fade away, in seconds.
const FADE_SECONDS := 0.8
