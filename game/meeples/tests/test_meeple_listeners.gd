extends GameTest
## Checks what a listener of meeple_changed may do at the moment a walk ends:
## kill the meeple, send it on, let it go, or close the village. The rows must
## stay right after each of them, and the walk that ended must not be told as
## an arrival.
##
## It also checks the other walks that end on the same tick. Whatever a
## listener of meeple_changed or of meeple_arrived does to one meeple, the
## walks of the meeples behind it in line still end.
##
## The picture is the only listener of meeple_changed today, and it changes
## nothing. A job listens to meeple_arrived. test_meeple_walk.gd checks a
## listener of that one.

## How close two spots must be to count as the same, in art pixels.
const CLOSE := 0.0001

var _village: Village
var _meeples: VillageMeeples
var _arrived: Array[int] = []
var _start: Vector2
## Where the listener sends the meeple on to.
var _far: Vector2
## What the listener does to the first meeple that stops walking: "kill",
## "send", "send and release", "release" or "close". It does it once.
var _answer := ""
## The meeple the listener of meeple_changed did that to.
var _answered: int = 0
## The village's random numbers before the tick on which the walk was over.
var _state_before: int = 0
## The three meeples whose walks end on one tick.
var _three: Array[int] = []
## Which of the two other meeples the listener of meeple_arrived kills on the
## first arrival: 0 or 1. With -1 it kills nobody.
var _kill_other: int = -1
## The meeple the listener of meeple_arrived killed.
var _killed: int = 0


## Hears the errors the engine reports while it is switched on.
class Listener:
	extends Logger
	var errors: PackedStringArray = []

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		_error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		errors.append("%s %s" % [code, rationale])


func before_each() -> void:
	_fresh_village()


func test_a_meeple_killed_by_a_listener_as_its_walk_ends_just_dies() -> void:
	var meeple := _walk_and_answer("kill")
	check_eq(int(_meeples.states[0]), VillageMeeples.DYING)
	check_eq(_meeples.dying.size(), 1)
	check_eq(_meeples.walkers.size(), 0)
	check_eq(_village.timers.sleeping(), 0, "no wake-up timer for a dying meeple")
	check_eq(_arrived.size(), 0, "a dying meeple does not arrive")
	MeepleTestKit.run(_village, 41)
	check(not _meeples.has_meeple(meeple), "it faded away")
	check_eq(_village.timers.sleeping(), 0)
	check_eq(_arrived.size(), 0)


func test_a_meeple_sent_on_by_a_listener_as_its_walk_ends_arrives_once() -> void:
	var meeple := _walk_and_answer("send")
	check_eq(_arrived.size(), 0, "it was sent on, so it has not arrived")
	check_eq(int(_meeples.states[0]), VillageMeeples.ON_JOB)
	check_eq(int(_meeples.walking[0]), 1, "it shows the walking pose")
	check_eq(_meeples.walkers.size(), 1)
	check_eq(_village.timers.sleeping(), 0)
	# 26.9 art pixels are 54 steps, and a walk is over one tick after its last step.
	MeepleTestKit.run(_village, 54)
	check_eq(_arrived.size(), 0)
	_village.tick()
	check(_meeples.spots[0].distance_to(_far) < CLOSE, "it walked to where it was sent on")
	check_eq(_arrived, [meeple] as Array[int], "one arrival, at the second place")
	MeepleTestKit.run(_village, 100)
	check_eq(_arrived.size(), 1)


func test_a_meeple_sent_on_and_let_go_by_a_listener_finishes_that_walk_first() -> void:
	_walk_and_answer("send and release")
	check_eq(int(_meeples.states[0]), VillageMeeples.FREED)
	check_eq(_meeples.walkers.size(), 1)
	check_eq(_village.timers.sleeping(), 0, "it walks, so it does not sleep")
	check_eq(_meeples.homes[0], _start, "its home is not set before it stops")
	# An idle meeple either sleeps on one timer or walks. Never both.
	var most := 0
	var least := 9
	for tick in 54:
		_village.tick()
		most = maxi(most, _village.timers.sleeping() + _meeples.walkers.size())
		least = mini(least, _meeples.walkers.size())
	check_eq(least, 1, "it walked all the way, nothing turned it round")
	_village.tick()
	check_eq(int(_meeples.states[0]), VillageMeeples.IDLE)
	check(_meeples.spots[0].distance_to(_far) < CLOSE, "it walked to where it was sent on")
	check_eq(_meeples.homes[0], _meeples.spots[0], "where it stopped is its home")
	for tick in 2000:
		_village.tick()
		most = maxi(most, _village.timers.sleeping() + _meeples.walkers.size())
	check_eq(most, 1, "one meeple: timers and walkers together")
	check_eq(_arrived.size(), 0, "it was let go, so no job is told")


func test_a_meeple_let_go_by_a_listener_as_its_walk_ends_rolls_one_pause() -> void:
	_walk_and_answer("release")
	check_eq(int(_meeples.states[0]), VillageMeeples.IDLE)
	check_eq(_meeples.homes[0], _meeples.spots[0], "where it stopped is its home")
	check_eq(_village.timers.sleeping(), 1, "one idle meeple, one wake-up timer")
	check_eq(_arrived.size(), 0, "it was let go, so no job is told")
	# Going idle uses one random number: the length of the pause.
	var twin := RandomNumberGenerator.new()
	twin.state = _state_before
	twin.randf_range(MeepleNumbers.PAUSE_MIN, MeepleNumbers.PAUSE_MAX)
	check_eq(_village.rng.state, twin.state, "it rolled one pause, not two")


func test_the_other_walks_of_a_tick_still_end_when_a_listener_kills_the_first() -> void:
	_three_walk_to_the_last_tick()
	_answer = "kill"
	_village.tick()
	check_eq(_answer, "", "the listener was asked as the first walk ended")
	check_eq(int(_meeples.states[_meeples.row_of(_answered)]), VillageMeeples.DYING)
	check_eq(_meeples.dying.size(), 1)
	check_eq(_meeples.walkers.size(), 0)
	_check_the_rest_arrived(_answered)


func test_the_other_walks_of_a_tick_still_end_when_a_listener_sends_the_first_on() -> void:
	_three_walk_to_the_last_tick()
	_answer = "send"
	_village.tick()
	check_eq(_answer, "", "the listener was asked as the first walk ended")
	check_eq(int(_meeples.walking[_meeples.row_of(_answered)]), 1, "the first one walks on")
	check_eq(_meeples.walkers.size(), 1, "only the one that was sent on still walks")
	_check_the_rest_arrived(_answered)


func test_a_walk_still_ends_when_an_arrival_listener_killed_the_one_before_it() -> void:
	# The village does not promise the order in which the arrivals of one tick
	# are told. So this runs twice, and on the first arrival the listener kills
	# one of the two other meeples, then the other one. In one of the two runs
	# the killed meeple is the next in line, and the third comes after it.
	for pick in 2:
		_fresh_village()
		_three_walk_to_the_last_tick()
		_kill_other = pick
		_village.tick()
		check_eq(_kill_other, -1, "the listener was asked on the first arrival")
		check_eq(int(_meeples.states[_meeples.row_of(_killed)]), VillageMeeples.DYING)
		check_eq(_meeples.dying.size(), 1)
		check_eq(_meeples.walkers.size(), 0)
		_check_the_rest_arrived(_killed)


func test_a_listener_may_close_the_village_as_a_walk_ends() -> void:
	_three_walk_to_the_last_tick()
	_answer = "close"
	var now := _village.now
	var listener := Listener.new()
	OS.add_logger(listener)
	_village.tick()
	# One more tick on the closed village. It does nothing.
	_village.tick()
	OS.remove_logger(listener)
	check_eq(_answer, "", "the listener was asked as the first walk ended")
	check(_village.is_closed(), "the village is closed")
	check_eq(_village.now, now + 1, "a closed village does not tick")
	check_eq(_meeples.count(), 0)
	var sizes := _meeples.sizes()
	for list_name: String in sizes:
		check_eq(sizes[list_name], 0, "%s is empty" % list_name)
	check_eq(_arrived.size(), 0, "nobody is told of a walk in a closed village")
	check_eq(listener.errors.size(), 0, "the engine reported: %s" % [listener.errors])


func _fresh_village() -> void:
	_village = MeepleTestKit.village(64)
	_meeples = MeepleTestKit.meeples(_village)
	_meeples.meeple_arrived.connect(_note_arrived)
	_meeples.meeple_changed.connect(_answer_change)
	_start = MeepleTestKit.middle()
	_far = _start + Vector2(20.0, 20.0)
	_arrived.clear()
	_three.clear()
	_answer = ""
	_answered = 0
	_kill_other = -1
	_killed = 0


func _note_arrived(meeple: int) -> void:
	_arrived.append(meeple)
	if _kill_other < 0:
		return
	var others := _three.duplicate()
	others.erase(meeple)
	_killed = others[_kill_other]
	_kill_other = -1
	check(_meeples.kill(_village, _killed), "a meeple whose walk is over can be killed")


## Adds three meeples, sends each on a job walk of 2 art pixels and runs to
## the tick before the one on which all three walks are over.
func _three_walk_to_the_last_tick() -> void:
	for index in 3:
		var spot := _start + Vector2(0.0, 6.0 * index)
		var meeple := MeepleTestKit.spawn(_village, spot)
		MeepleTestKit.send(_village, meeple, spot + Vector2(2.0, 0.0))
		_three.append(meeple)
	# 2 art pixels are 4 steps, and a walk is over one tick after its last step.
	MeepleTestKit.run(_village, 4)
	check_eq(_meeples.walkers.size(), 3, "all three still walk")
	check_eq(_arrived.size(), 0)


## Checks that the two of the three meeples that are not [param taken] were
## told as arrived on this tick, once each, and stand on their job.
func _check_the_rest_arrived(taken: int) -> void:
	check(_three.has(taken), "the listener took one of the three")
	check_eq(_arrived.size(), 2, "the two others arrived: %s" % [_arrived])
	check(not _arrived.has(taken), "the one the listener took did not arrive")
	for meeple in _three:
		if meeple == taken:
			continue
		var row := _meeples.row_of(meeple)
		check(_arrived.has(meeple), "meeple %d was told as arrived" % meeple)
		check_eq(int(_meeples.walking[row]), 0, "meeple %d stands" % meeple)
		check_eq(int(_meeples.states[row]), VillageMeeples.ON_JOB)
	check_eq(_village.timers.sleeping(), 0, "nobody is idle, so nobody sleeps")


## Adds one meeple, sends it on a job walk of 2 art pixels and runs to the
## tick on which that walk is over. The listener does [param answer] to the
## meeple at that moment. Returns the meeple.
func _walk_and_answer(answer: String) -> int:
	var meeple := MeepleTestKit.spawn(_village, _start)
	MeepleTestKit.send(_village, meeple, _start + Vector2(2.0, 0.0))
	_answer = answer
	# 2 art pixels are 4 steps, and a walk is over one tick after its last step.
	MeepleTestKit.run(_village, 4)
	check_eq(_answer, answer, "the walk is not over yet")
	_state_before = _village.rng.state
	_village.tick()
	check_eq(_answer, "", "the listener was asked as the walk ended")
	return meeple


func _answer_change(row: int) -> void:
	# The signal also comes when a walk starts. Only the end of one is answered.
	if _answer == "" or _meeples.walking[row] == 1:
		return
	var answer := _answer
	_answer = ""
	var meeple := _meeples.ids[row]
	_answered = meeple
	match answer:
		"kill":
			check(_meeples.kill(_village, meeple), "it can be killed here")
		"send":
			MeepleTestKit.send(_village, meeple, _far)
		"send and release":
			MeepleTestKit.send(_village, meeple, _far)
			check(_meeples.release(_village, meeple), "a meeple on a job can be let go")
		"release":
			check(_meeples.release(_village, meeple), "a meeple on a job can be let go")
		"close":
			_village.close()
