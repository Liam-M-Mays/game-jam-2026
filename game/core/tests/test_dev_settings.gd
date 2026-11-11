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


func test_no_world_seed_is_fixed() -> void:
	check_eq(DevSettings.new().world_seed, 0, "0 means a new random seed for each game")
	check_eq(DevSettings.load_settings().world_seed, 0, "the saved settings fix no seed")
