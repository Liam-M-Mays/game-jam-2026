extends GameTest
## Checks the layer rules of the design (Decision 33 in docs/core-design.md).
##
## Game sits above the villages, so no simulation script may name it. The
## bottom layer is everything in game/core/ except game.gd: it may name
## neither a village nor Game. The test reads the scripts as text. A name
## inside a comment is allowed.

const ROOTS: Array[String] = ["res://game", "res://addons"]
const CORE := "res://game/core"
const GAME_SCRIPT := "res://game/core/game.gd"
const EVENTS_SCRIPT := "res://game/core/events.gd"
const GAME_NAME := "\\bGame(Service)?\\b"
const VILLAGE_CLASS := "\\bVillage"
const VILLAGE_ANY_CASE := "(?i)village"


func test_no_simulation_script_names_the_game_service() -> void:
	var scripts: Array[String] = []
	for root in ROOTS:
		_collect(root, false, true, scripts)
	check(scripts.size() >= 9, "the scripts in sim/ folders were found: %d" % scripts.size())
	check(scripts.has("res://game/village/sim/village.gd"), "the village script is one of them")
	var game_name := RegEx.create_from_string(GAME_NAME)
	for path in scripts:
		for hit in _lines_that_name(path, game_name):
			fail("%s names Game on line %d" % [path, hit])


func test_the_bottom_layer_names_no_village_and_no_game() -> void:
	var scripts := _bottom_layer_scripts()
	check(scripts.has(EVENTS_SCRIPT), "events.gd is checked")
	check(scripts.has("res://game/core/dev_settings.gd"), "dev_settings.gd is checked")
	check(scripts.has("res://game/core/sim/tick_clock.gd"), "the clock is checked")
	check(scripts.has("res://game/core/sim/tick_timers.gd"), "the timers are checked")
	check(not scripts.has(GAME_SCRIPT), "game.gd is the one that may know the villages")
	for path in scripts:
		check(not path.contains("/tests/"), "%s is a test and is left out" % path)
	var village_class := RegEx.create_from_string(VILLAGE_CLASS)
	var game_name := RegEx.create_from_string(GAME_NAME)
	for path in scripts:
		for hit in _lines_that_name(path, village_class):
			fail("%s names a village on line %d" % [path, hit])
		for hit in _lines_that_name(path, game_name):
			fail("%s names Game on line %d" % [path, hit])


func test_the_events_service_names_no_village_in_any_spelling() -> void:
	var class_line := RegEx.create_from_string("^class_name EventsService$")
	check_eq(_lines_that_name(EVENTS_SCRIPT, class_line).size(), 1, "events.gd was read")
	var village_word := RegEx.create_from_string(VILLAGE_ANY_CASE)
	var hits := _lines_that_name(EVENTS_SCRIPT, village_word)
	check_eq(hits.size(), 0, "lines of events.gd that name a village")


func test_the_check_sees_a_name_in_code_and_not_in_a_comment() -> void:
	var game_name := RegEx.create_from_string(GAME_NAME)
	check(game_name.search(_code_of("\tGame.paused = true")) != null, "Game in code is seen")
	check(game_name.search(_code_of("var game := GameService.new()")) != null, "so is its class")
	check(game_name.search(_code_of("## The Game service ticks it.")) == null, "not in a comment")
	check(game_name.search(_code_of("now += 1  # Game does this")) == null, "not after the code")
	check(game_name.search(_code_of("var games_won := 0")) == null, "not inside another word")
	check_eq(_code_of('print("# not a comment")  # a comment'), 'print("# not a comment")  ')
	var village_class := RegEx.create_from_string(VILLAGE_CLASS)
	check(village_class.search(_code_of("signal x(v: Village)")) != null, "the class is seen")
	check(village_class.search(_code_of("var grid: VillageGrid")) != null, "and its family")
	check(village_class.search(_code_of("var village_id := 0")) == null, "a small v is not")
	var village_word := RegEx.create_from_string(VILLAGE_ANY_CASE)
	check(village_word.search(_code_of("signal toast(village_id: int)")) != null, "any case")
	check(village_word.search(_code_of("signal x(inVillage: bool)")) != null, "inside a word")
	check(village_word.search(_code_of("signal toast(text: String)")) == null, "plain news")


## Every script of the bottom layer: all of game/core/ but game.gd and the tests.
func _bottom_layer_scripts() -> Array[String]:
	var found: Array[String] = []
	_collect(CORE, true, false, found)
	found.erase(GAME_SCRIPT)
	found.sort()
	return found


## Adds the scripts under [param dir] to [param found]. With [param only_sim]
## only the ones in a sim/ folder count. A tests/ folder is left out unless
## [param only_sim] is on, where it cannot be inside a sim/ folder anyway.
func _collect(dir: String, taking: bool, only_sim: bool, found: Array[String]) -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return
	for sub in access.get_directories():
		if sub.begins_with(".") or (not only_sim and sub == "tests"):
			continue
		_collect(dir.path_join(sub), taking or sub == "sim", only_sim, found)
	if taking:
		for file in access.get_files():
			if file.get_extension() == "gd":
				found.append(dir.path_join(file))


## The numbers of the lines of [param path] whose code matches [param word].
func _lines_that_name(path: String, word: RegEx) -> Array[int]:
	var hits: Array[int] = []
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for index in lines.size():
		if word.search(_code_of(lines[index])) != null:
			hits.append(index + 1)
	return hits


## The line without its comment. A '#' inside a string is kept.
func _code_of(line: String) -> String:
	var quote := ""
	for index in line.length():
		var letter := line[index]
		if quote != "":
			if letter == quote and line[index - 1] != "\\":
				quote = ""
		elif letter == '"' or letter == "'":
			quote = letter
		elif letter == "#":
			return line.substr(0, index)
	return line
