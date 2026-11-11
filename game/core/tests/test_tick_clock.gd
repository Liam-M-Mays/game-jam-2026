extends GameTest
## Checks the clock that turns real time into ticks.

const TICKS_PER_SECOND := 20


func test_one_second_runs_20_ticks_at_x1_and_60_ticks_at_x3() -> void:
	check_eq(_ticks_in_one_second(1.0, 60), 20)
	check_eq(_ticks_in_one_second(3.0, 60), 60)


func test_the_frame_rate_does_not_change_the_number_of_ticks() -> void:
	for frames: int in [30, 60, 75, 144, 240]:
		check_eq(_ticks_in_one_second(1.0, frames), 20, "x1 at %d frames a second" % frames)
		check_eq(_ticks_in_one_second(3.0, frames), 60, "x3 at %d frames a second" % frames)


func test_a_speed_between_whole_numbers_works() -> void:
	check_eq(_ticks_in_one_second(1.5, 60), 30)
	check_eq(_ticks_in_one_second(2.0, 60), 40)


func test_uneven_frames_add_up_to_the_same_ticks() -> void:
	var clock := TickClock.new(TICKS_PER_SECOND)
	var ticks := 0
	for i in 20:
		ticks += clock.advance(0.011)
		ticks += clock.advance(0.039)
	check_eq(ticks, 20)


func test_ten_seconds_do_not_drift() -> void:
	var clock := TickClock.new(TICKS_PER_SECOND)
	clock.speed = 3.0
	var ticks := 0
	for i in 600:
		ticks += clock.advance(1.0 / 60.0)
	check_eq(ticks, 600)


func test_a_paused_clock_runs_no_tick() -> void:
	var clock := TickClock.new(TICKS_PER_SECOND)
	clock.paused = true
	var ticks := 0
	for i in 60:
		ticks += clock.advance(1.0 / 60.0)
	check_eq(ticks, 0)
	clock.paused = false
	check_eq(clock.advance(0.05), 1, "the time spent paused was not saved up")


func test_one_slow_frame_counts_as_a_quarter_second() -> void:
	var clock := TickClock.new(TICKS_PER_SECOND)
	check_eq(clock.advance(5.0), 5)


func test_the_fraction_says_how_far_the_next_tick_is() -> void:
	var clock := TickClock.new(TICKS_PER_SECOND)
	check_eq(clock.advance(0.025), 0)
	check_near(clock.fraction(), 0.5)
	check_eq(clock.advance(0.0375), 1)
	check_near(clock.fraction(), 0.25)
	clock.reset()
	check_near(clock.fraction(), 0.0)


func _ticks_in_one_second(speed: float, frames: int) -> int:
	var clock := TickClock.new(TICKS_PER_SECOND)
	clock.speed = speed
	var ticks := 0
	for i in frames:
		ticks += clock.advance(1.0 / frames)
	return ticks
