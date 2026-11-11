extends GameTest
## Checks the timers that cost nothing while they wait.

var _woke: Array[String] = []


func test_1000_sleeping_timers_add_no_step_to_a_tick() -> void:
	var timers := TickTimers.new()
	for i in 1000:
		timers.wake_at(5000 + i, _wake.bind("late"))
	for tick in range(1, 2001):
		timers.run(tick)
	check_eq(timers.steps, 0, "steps taken in 2,000 ticks with 1,000 timers asleep")
	check_eq(timers.sleeping(), 1000)
	check_eq(_woke.size(), 0)


func test_a_tick_only_looks_at_the_timers_that_are_due() -> void:
	var timers := TickTimers.new()
	for i in 1000:
		timers.wake_at(5000, _wake.bind("late"))
	timers.wake_at(10, _wake.bind("early"))
	for tick in range(1, 11):
		timers.run(tick)
	check_eq(timers.steps, 1, "only the one timer that was due was looked at")
	check_eq(_woke, ["early"] as Array[String])
	for tick in range(11, 5001):
		timers.run(tick)
	check_eq(timers.steps, 1001, "each timer was looked at once, on its own tick")
	check_eq(timers.sleeping(), 0)


func test_a_timer_wakes_once_on_its_tick() -> void:
	var timers := TickTimers.new()
	timers.wake_at(3, _wake.bind("a"))
	check_eq(timers.run(1), 0)
	check_eq(timers.run(2), 0)
	check_eq(timers.run(3), 1)
	check_eq(timers.run(4), 0)
	check_eq(_woke, ["a"] as Array[String])


func test_timers_on_the_same_tick_wake_in_the_order_they_were_set() -> void:
	var timers := TickTimers.new()
	timers.wake_at(2, _wake.bind("first"))
	timers.wake_at(2, _wake.bind("second"))
	timers.wake_at(2, _wake.bind("third"))
	timers.run(1)
	timers.run(2)
	check_eq(_woke, ["first", "second", "third"] as Array[String])


func test_wake_after_counts_from_the_tick_that_ran_last() -> void:
	var timers := TickTimers.new()
	timers.run(1)
	timers.run(2)
	var timer := timers.wake_after(3, _wake.bind("a"))
	timers.run(3)
	timers.run(4)
	check(timers.is_sleeping(timer), "it should still sleep on tick 4")
	timers.run(5)
	check_eq(_woke, ["a"] as Array[String])
	check(not timers.is_sleeping(timer), "it should have woken on tick 5")


func test_a_cancelled_timer_never_wakes() -> void:
	var timers := TickTimers.new()
	var timer := timers.wake_at(2, _wake.bind("a"))
	check(timers.cancel(timer), "a sleeping timer can be cancelled")
	check(not timers.cancel(timer), "it cannot be cancelled twice")
	timers.run(1)
	timers.run(2)
	check_eq(_woke.size(), 0)
	check_eq(timers.sleeping(), 0)


func test_a_timer_set_for_now_or_the_past_wakes_on_the_next_tick() -> void:
	var timers := TickTimers.new()
	timers.run(1)
	timers.wake_at(1, _wake.bind("now"))
	timers.wake_at(-7, _wake.bind("past"))
	timers.run(2)
	check_eq(_woke, ["now", "past"] as Array[String])


func test_a_timer_can_set_the_next_one_while_it_wakes() -> void:
	var timers := TickTimers.new()
	timers.wake_at(1, _wake_and_repeat.bind(timers, 2))
	for tick in range(1, 8):
		timers.run(tick)
	check_eq(_woke, ["repeat", "repeat", "repeat", "repeat"] as Array[String])
	check_eq(timers.sleeping(), 1)
	# The sleeping timer holds the timers object itself, so let it go.
	timers.clear()


func test_run_hands_what_it_is_given_to_every_timer_as_its_first_argument() -> void:
	var timers := TickTimers.new()
	timers.wake_at(1, _wake_handed.bind("first"))
	timers.wake_at(2, _wake_handed.bind("second"))
	timers.run(1, "village")
	timers.run(2, "village")
	check_eq(_woke, ["village first", "village second"] as Array[String])


func test_closed_timers_drop_everything_and_take_no_new_timer() -> void:
	var timers := TickTimers.new()
	var timer := timers.wake_at(2, _wake.bind("before"))
	timers.close()
	check(timers.is_closed(), "the timers say they are closed")
	check(not timers.is_sleeping(timer), "the timer that slept is dropped")
	check_eq(timers.wake_at(3, _wake.bind("after")), TickTimers.NO_TIMER)
	check_eq(timers.wake_after(1, _wake.bind("after")), TickTimers.NO_TIMER)
	check_eq(timers.sleeping(), 0)
	for tick in range(1, 5):
		timers.run(tick)
	check_eq(_woke.size(), 0)


func test_clear_drops_every_timer_without_waking_it() -> void:
	var timers := TickTimers.new()
	timers.wake_at(2, _wake.bind("a"))
	timers.wake_at(3, _wake.bind("b"))
	timers.clear()
	timers.run(1)
	timers.run(2)
	timers.run(3)
	check_eq(_woke.size(), 0)
	check_eq(timers.sleeping(), 0)


func _wake(tag: String) -> void:
	_woke.append(tag)


func _wake_handed(handed: String, tag: String) -> void:
	_woke.append("%s %s" % [handed, tag])


func _wake_and_repeat(timers: TickTimers, every: int) -> void:
	_woke.append("repeat")
	timers.wake_after(every, _wake_and_repeat.bind(timers, every))
