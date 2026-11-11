extends GameTest
## Checks what a listener of meeple_changed may do at the moment a walk ends:
## kill the meeple, send it on, or let it go. The rows must stay right after
## each of them, and the walk that ended must not be told as an arrival.
##
## The picture is the only listener of that signal today, and it changes
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
## What the listener does to the meeple that stops walking: "kill", "send",
## "send and release" or "release". It does it once.
var _answer := ""
## The village's random numbers before the tick on which the walk was over.
var _state_before: int = 0


func before_each() -> void:
	_village = MeepleTestKit.village(64)
	_meeples = MeepleTestKit.meeples(_village)
	_meeples.meeple_arrived.connect(_note_arrived)
	_meeples.meeple_changed.connect(_answer_change)
	_start = MeepleTestKit.middle()
	_far = _start + Vector2(20.0, 20.0)


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


func _note_arrived(meeple: int) -> void:
	_arrived.append(meeple)


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
