extends GameTest
## Checks the layer rules of the design (Decision 33 in docs/core-design.md).
##
## Game sits above the villages, so no simulation script may name it. Events
## is part of the bottom layer, so it may not name a village. The test reads
## the scripts as text. A name inside a comment is allowed.

const ROOTS: Array[String] = ["res://game", "res://addons"]
const EVENTS_SCRIPT := "res://game/core/events.gd"


func test_no_simulation_script_names_the_game_service() -> void:
	var scripts := _sim_scripts()
	check(scripts.size() >= 9, "the scripts in sim/ folders were found: %d" % scripts.size())
	check(scripts.has("res://game/village/sim/village.gd"), "the village script is one of them")
	var game_name := RegEx.create_from_string("\\bGame(Service)?\\b")
	for path in scripts:
		for hit in _lines_that_name(path, game_name):
			fail("%s names Game on line %d" % [path, hit])


func test_the_events_service_does_not_name_a_village() -> void:
	var village_name := RegEx.create_from_string("\\bVillage")
	var hits := _lines_that_name(EVENTS_SCRIPT, village_name)
	check_eq(hits.size(), 0, "lines of events.gd that name a village")
	check(_lines_that_name(EVENTS_SCRIPT, RegEx.create_from_string("\\bsignal\\b")).size() >= 1)


func test_the_check_sees_a_name_in_code_and_not_in_a_comment() -> void:
	var game_name := RegEx.create_from_string("\\bGame(Service)?\\b")
	check(game_name.search(_code_of("\tGame.paused = true")) != null, "Game in code is seen")
	check(game_name.search(_code_of("var game := GameService.new()")) != null, "so is its class")
	check(game_name.search(_code_of("## The Game service ticks it.")) == null, "not in a comment")
	check(game_name.search(_code_of("now += 1  # Game does this")) == null, "not after the code")
	check(game_name.search(_code_of("var games_won := 0")) == null, "not inside another word")
	check_eq(_code_of('print("# not a comment")  # a comment'), 'print("# not a comment")  ')


## Every script that sits in a sim/ folder of the new game.
func _sim_scripts() -> Array[String]:
	var found: Array[String] = []
	for root in ROOTS:
		_collect(root, false, found)
	found.sort()
	return found


func _collect(dir: String, in_sim: bool, found: Array[String]) -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return
	for sub in access.get_directories():
		if not sub.begins_with("."):
			_collect(dir.path_join(sub), in_sim or sub == "sim", found)
	if in_sim:
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
