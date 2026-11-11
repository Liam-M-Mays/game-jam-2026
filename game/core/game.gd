class_name GameService
extends Node
## The Game service: the session, pause, game speed and the village in view.
##
## It is loaded as the global [code]Game[/code]. It owns the tick clock and
## ticks every village of the session, shown or not. It holds no rule and no
## data of a village: those are in [Village]. With no village it does nothing,
## so it stays quiet in the old jam game and in the menu.

## Turns the seconds of a frame into ticks. Its tick rate comes from [DevSettings].
var clock: TickClock

## While true, no village ticks. Setting it during a tick lets that tick
## finish and stops the rest of the frame.
var paused: bool:
	get:
		return clock.paused
	set(value):
		if value == clock.paused:
			return
		clock.paused = value
		Events.paused_changed.emit(value)

## Game speed. 3.0 means three times the ticks per second. It never changes
## the engine's time scale.
var speed: float:
	get:
		return clock.speed
	set(value):
		var next := maxf(value, 0.0)
		if is_equal_approx(next, clock.speed):
			return
		clock.speed = next
		Events.speed_changed.emit(next)

## The village the player is looking at, or null. Change it with [method show_village].
var village_in_view: Village = null

var _villages: Array[Village] = []


func _init() -> void:
	clock = TickClock.new(DevSettings.load_settings().ticks_per_second)


func _process(delta: float) -> void:
	advance(delta)


## Starts a new session: closes every village of the old one, and sets pause,
## speed and the clock back.
func new_session() -> void:
	end_session()


## Ends the session: closes every village, and sets pause, speed and the clock
## back. Nothing of the old session is left afterwards.
func end_session() -> void:
	for village in villages():
		remove_village(village)
	paused = false
	speed = 1.0
	clock.reset()


## Makes a village from [param village_seed] and adds it to the session.
func new_village(village_seed: int) -> Village:
	var village := Village.new(village_seed, clock.ticks_per_second)
	add_village(village)
	return village


## Adds [param village] to the session. From now on it ticks, shown or not.
func add_village(village: Village) -> void:
	if village == null or _villages.has(village):
		return
	_villages.append(village)
	Events.village_added.emit(village)


## Takes [param village] out of the session and closes it.
func remove_village(village: Village) -> void:
	if not _villages.has(village):
		return
	if village_in_view == village:
		show_village(null)
	_villages.erase(village)
	village.close()
	Events.village_removed.emit(village)


## The villages of the session, in the order they were added.
func villages() -> Array[Village]:
	return _villages.duplicate()


## How many villages the session has.
func village_count() -> int:
	return _villages.size()


## Puts [param village] in view. Pass null for no village. A village that is
## not in view keeps ticking in full.
func show_village(village: Village) -> void:
	if village != null and not _villages.has(village):
		return
	if village == village_in_view:
		return
	village_in_view = village
	Events.village_in_view_changed.emit(village)


## Takes [param seconds] of real time and runs the ticks they are worth, on
## every village. Returns how many ticks really ran. A frame calls this once.
## A pause that is set during a tick stops the ticks that were still to come.
## A village that is removed during a tick does not make another one miss it.
func advance(seconds: float) -> int:
	var ticks := clock.advance(seconds)
	var ran := 0
	while ran < ticks and not clock.paused:
		for village in villages():
			village.tick()
		ran += 1
	return ran
