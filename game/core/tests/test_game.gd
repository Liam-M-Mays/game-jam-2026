extends GameTest
## Checks the Game service: the session, pause, speed and the village in view.
##
## Each test makes its own Game, so the tests do not share a session. Pause
## and speed news goes through the real global Events. News about villages
## comes from the Game itself.

const FRAMES := 60
const WOOD := 1
const MAP := Vector2i(12, 12)

var _game: GameService
var _news: Array[String] = []


## A small part for these tests. It sleeps on a timer, and each time it wakes
## it stands a thing on a random cell, with the village's own random numbers.
class Busy:
	extends VillagePart
	var wakes: int = 0
	var placed: int = 0

	## Goes to sleep for the first time.
	func start(village: Village) -> void:
		village.timers.wake_after(village.rng.randi_range(2, 4), _wake)

	## How often it woke and how many things it placed.
	func snapshot() -> Dictionary:
		return {"wakes": wakes, "placed": placed}

	func _wake(village: Village) -> void:
		wakes += 1
		var rng := village.rng
		var anchor := Vector2i(rng.randi_range(0, MAP.x - 1), rng.randi_range(0, MAP.y - 1))
		if village.grid.place(village.new_id(), anchor):
			placed += 1
		village.timers.wake_after(rng.randi_range(2, 4), _wake)


## Makes a fresh Game and listens to every event it sends.
func before_each() -> void:
	_game = GameService.new()
	Events.speed_changed.connect(_on_speed_changed)
	Events.paused_changed.connect(_on_paused_changed)
	_game.village_in_view_changed.connect(_on_village_in_view_changed)
	_game.village_added.connect(_on_village_added)
	_game.village_removed.connect(_on_village_removed)


## Stops listening, ends the session and frees the Game.
func after_each() -> void:
	Events.speed_changed.disconnect(_on_speed_changed)
	Events.paused_changed.disconnect(_on_paused_changed)
	_game.village_in_view_changed.disconnect(_on_village_in_view_changed)
	_game.village_added.disconnect(_on_village_added)
	_game.village_removed.disconnect(_on_village_removed)
	_game.end_session()
	_game.free()


func test_the_tick_rate_comes_from_the_dev_settings() -> void:
	check_eq(_game.clock.ticks_per_second, DevSettings.load_settings().ticks_per_second)
	var village := _game.new_village(1)
	check_eq(village.ticks_per_second, DevSettings.load_settings().ticks_per_second)


func test_one_second_of_real_time_runs_20_ticks_at_x1_and_60_ticks_at_x3() -> void:
	_game.clock.ticks_per_second = 20
	var village := _game.new_village(1)
	check_eq(_run_one_second(), 20)
	check_eq(village.now, 20)
	_game.speed = 3.0
	check_eq(_run_one_second(), 60)
	check_eq(village.now, 80)


func test_game_speed_does_not_change_the_engine_time_scale() -> void:
	var before := Engine.time_scale
	_game.new_village(1)
	_game.speed = 3.0
	_run_one_second()
	check_eq(Engine.time_scale, before)
	_game.paused = true
	check_eq(Engine.time_scale, before)


func test_a_paused_game_runs_no_tick() -> void:
	var village := _game.new_village(1)
	_game.paused = true
	check_eq(_run_one_second(), 0)
	check_eq(village.now, 0)
	_game.paused = false
	check_eq(_run_one_second(), _game.clock.ticks_per_second)


func test_every_village_gets_every_tick() -> void:
	var first := _game.new_village(1)
	var second := _game.new_village(2)
	var ticks := _run_one_second()
	check_eq(first.now, ticks)
	check_eq(second.now, ticks)


func test_a_village_that_is_not_in_view_ticks_the_same() -> void:
	_game.clock.ticks_per_second = 20
	var shown := _busy_village(7)
	var hidden := _busy_village(7)
	_game.show_village(shown)
	var ticks := _run_one_second()
	check_eq(_game.village_in_view, shown)
	check_eq(ticks, 20)
	check_eq(shown.now, ticks)
	check_eq(hidden.now, ticks)
	var hidden_part: Busy = hidden.part(&"busy")
	check(hidden_part.wakes >= 4, "the hidden village woke its timers: %d" % hidden_part.wakes)
	check(hidden_part.placed >= 1, "and its part placed things on its grid")
	check_eq(hidden.snapshot(), shown.snapshot())
	var other_seed := _busy_village(8)
	_run_one_second()
	check(hidden.snapshot()["grid"] != other_seed.snapshot()["grid"], "the compare can fail")


func test_a_pause_set_during_a_tick_stops_the_rest_of_the_frame() -> void:
	_game.clock.ticks_per_second = 20
	var village := _game.new_village(1)
	village.timers.wake_at(2, _pause_from_a_timer)
	check_eq(_game.advance(0.25), 2, "5 ticks were due and 2 really ran")
	check_eq(village.now, 2)
	check(_game.paused, "the timer paused the game on tick 2")
	check_eq(_game.advance(0.25), 0)
	_game.paused = false
	check_eq(_game.advance(0.05), 1, "the ticks that were cut off are not saved up")
	check_eq(village.now, 3)


func test_a_village_removed_during_a_tick_does_not_make_another_miss_it() -> void:
	_game.clock.ticks_per_second = 20
	var first := _game.new_village(1)
	var second := _game.new_village(2)
	var third := _game.new_village(3)
	first.timers.wake_at(2, _remove_from_a_timer)
	check_eq(_game.advance(0.25), 5)
	check(first.is_closed(), "the first village removed itself on tick 2")
	check_eq(first.now, 2)
	check_eq(second.now, 5, "the village after it got every tick")
	check_eq(third.now, 5, "and so did the last one")
	check_eq(_game.village_count(), 2)


func test_the_village_in_view_can_be_changed_and_cleared() -> void:
	var first := _game.new_village(1)
	var second := _game.new_village(2)
	check_eq(_game.village_in_view, null)
	_game.show_village(first)
	_game.show_village(second)
	_game.show_village(null)
	check_eq(
		_news, ["added", "added", "view village", "view village", "view null"] as Array[String]
	)


func test_a_village_outside_the_session_cannot_be_put_in_view() -> void:
	var stranger := Village.new(1, 20)
	_game.show_village(stranger)
	check_eq(_game.village_in_view, null)
	stranger.close()


func test_removing_the_village_in_view_clears_the_view_and_closes_it() -> void:
	var village := _game.new_village(1)
	_game.show_village(village)
	_game.remove_village(village)
	check_eq(_game.village_in_view, null)
	check_eq(_game.village_count(), 0)
	check(village.is_closed(), "a removed village is closed")
	check_eq(_news, ["added", "view village", "view null", "removed"] as Array[String])


func test_a_new_session_leaves_nothing_of_the_old_one() -> void:
	var cell := Vector2i(2, 2)
	var village := _game.new_village(1)
	village.grid.add_cell(cell)
	village.grid.drops.add(cell, WOOD, 3)
	village.timers.wake_at(1000, _on_timer)
	_game.show_village(village)
	_game.speed = 3.0
	_game.clock.advance(0.01)
	_game.paused = true
	_game.new_session()
	check_eq(_game.village_count(), 0)
	check_eq(_game.village_in_view, null)
	check_eq(_game.speed, 1.0)
	check_eq(_game.paused, false)
	check_near(_game.clock.fraction(), 0.0)
	check(village.is_closed(), "the old village is closed")
	check_eq(village.timers.sleeping(), 0, "the timers of the old village are gone")
	var fresh := _game.new_village(1)
	fresh.grid.add_cell(cell)
	check_eq(fresh.now, 0)
	check_eq(fresh.timers.sleeping(), 0, "a new village starts with no timer")
	check(not fresh.grid.drops.has_any(cell), "and with no drop of the old one")
	check_eq(fresh.grid.drops.count_at(cell, WOOD), 0)
	_run_one_second()
	check_eq(_news.count("timer"), 0, "no timer of the old session woke in the new one")


func test_pause_and_speed_send_news_only_when_they_change() -> void:
	_game.speed = 3.0
	_game.speed = 3.0
	_game.paused = true
	_game.paused = true
	_game.paused = false
	check_eq(_news, ["speed 3.0", "paused true", "paused false"] as Array[String])


func test_with_no_village_nothing_happens() -> void:
	check_eq(_game.village_count(), 0)
	_run_one_second()
	check_eq(_news.size(), 0)


func _busy_village(village_seed: int) -> Village:
	var village := _game.new_village(village_seed)
	for cell in GridLayout.block(Vector2i(0, 0), MAP):
		village.grid.add_cell(cell)
	village.add_part(&"busy", Busy.new())
	return village


func _pause_from_a_timer(_village: Village) -> void:
	_game.paused = true


func _remove_from_a_timer(village: Village) -> void:
	_game.remove_village(village)


func _on_timer(_village: Village) -> void:
	_news.append("timer")


func _run_one_second() -> int:
	var ticks := 0
	for i in FRAMES:
		ticks += _game.advance(1.0 / FRAMES)
	return ticks


func _on_speed_changed(speed: float) -> void:
	_news.append("speed %s" % speed)


func _on_paused_changed(paused: bool) -> void:
	_news.append("paused %s" % paused)


func _on_village_in_view_changed(village: Village) -> void:
	_news.append("view %s" % ("null" if village == null else "village"))


func _on_village_added(_village: Village) -> void:
	_news.append("added")


func _on_village_removed(_village: Village) -> void:
	_news.append("removed")
