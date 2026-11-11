extends GameTest
## Checks the saved dev settings. It is also the sample test: copy it to start a new one.


func test_the_saved_settings_load() -> void:
	var settings := DevSettings.load_settings()
	check(settings != null, "dev_settings.tres did not load")


func test_the_world_has_a_sensible_size() -> void:
	var settings := DevSettings.load_settings()
	check(settings.world_cells >= 500, "the world is too small to play on")
	check(settings.world_cells <= 1000000, "the world is bigger than anything measured")


func test_the_tick_rate_starts_at_twenty() -> void:
	check_eq(DevSettings.new().ticks_per_second, 20)
