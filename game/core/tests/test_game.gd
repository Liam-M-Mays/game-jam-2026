extends GameTest
## Checks the Game service: the session, pause, speed and the village in view.
##
## Each test makes its own Game, so the tests do not share a session. The news
## it sends goes through the real global Events.

const FRAMES := 60

var _game: GameService
var _news: Array[String] = []


## Makes a fresh Game and listens to every event it sends.
func before_each() -> void:
	_game = GameService.new()
	Events.speed_changed.connect(_on_speed_changed)
	Events.paused_changed.connect(_on_paused_changed)
	Events.village_in_view_changed.connect(_on_village_in_view_changed)
	Events.village_added.connect(_on_village_added)
	Events.village_removed.connect(_on_village_removed)


## Stops listening, ends the session and frees the Game.
func after_each() -> void:
	Events.speed_changed.disconnect(_on_speed_changed)
	Events.paused_changed.disconnect(_on_paused_changed)
	Events.village_in_view_changed.disconnect(_on_village_in_view_changed)
	Events.village_added.disconnect(_on_village_added)
	Events.village_removed.disconnect(_on_village_removed)
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
	var shown := _game.new_village(7)
	var hidden := _game.new_village(7)
	_game.show_village(shown)
	_run_one_second()
	check_eq(_game.village_in_view, shown)
	check_eq(hidden.now, shown.now)
	check_eq(hidden.snapshot(), shown.snapshot())


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
	var village := _game.new_village(1)
	village.timers.wake_at(1000, _on_speed_changed.bind(0.0))
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
	check_eq(village.timers.sleeping(), 0, "the timers of the old village are gone")


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
