extends Node
## Runs every test script of the new game with no window.
##
## Start it with [code]bash .github/ci/run_tests.sh[/code]. It prints one line
## per test and ends with a [code]TESTS DONE[/code] line, which
## [code].github/ci/checks.py[/code] turns into a pass or a fail.
## The page [code]docs/testing.md[/code] explains how to add a test.

## The folders that are searched for test scripts.
const ROOTS: Array[String] = ["res://game", "res://addons"]
## A test script and a test method both start with this.
const PREFIX := "test_"
## A run that takes longer than this many seconds is stopped as failed.
const TIMEOUT_SECONDS := 300.0
## Pass [code]-- --only=<text>[/code] to run only the scripts whose path holds the text.
const ONLY_ARG := "--only="

var _passed := 0
var _failed := 0


func _ready() -> void:
	get_tree().create_timer(TIMEOUT_SECONDS, true, false, true).timeout.connect(_on_timeout)
	var only := _only()
	var files := 0
	for path in _find_tests():
		if only != "" and not path.contains(only):
			continue
		files += 1
		await _run_file(path)
	if files == 0:
		_failed += 1
		printerr("TEST FAIL (runner) | no test script was found")
	_finish(files)


func _run_file(path: String) -> void:
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		_fail(path, ["the script does not load"])
		return
	if not script.new() is GameTest:
		_fail(path, ["the script does not extend GameTest"])
		return
	var methods := _test_methods(script)
	if methods.is_empty():
		_fail(path, ["the script has no method that starts with %s" % PREFIX])
		return
	for method in methods:
		await _run_test(script, path, method)


func _run_test(script: GDScript, path: String, method: String) -> void:
	var test_name := "%s::%s" % [path, method]
	printerr("TEST RUN ", test_name)
	var test: GameTest = script.new()
	test.tree = get_tree()
	test.before_each()
	await test.call(method)
	test.after_each()
	var problems := test.failures().duplicate()
	if problems.is_empty() and test.check_count() == 0:
		problems.append("the test ran no check. It may have stopped on an error")
	if problems.is_empty():
		_passed += 1
		printerr("TEST PASS ", test_name)
	else:
		_fail(test_name, problems)


func _fail(test_name: String, problems: Array) -> void:
	_failed += 1
	for problem: String in problems:
		printerr("TEST FAIL ", test_name, " | ", problem)


func _finish(files: int) -> void:
	printerr("TESTS DONE passed=", _passed, " failed=", _failed, " files=", files)
	get_tree().quit(1 if _failed > 0 else 0)


func _on_timeout() -> void:
	_failed += 1
	printerr("TEST FAIL (runner) | the run took longer than %d seconds" % int(TIMEOUT_SECONDS))
	_finish(-1)


func _only() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(ONLY_ARG):
			return arg.trim_prefix(ONLY_ARG)
	return ""


func _test_methods(script: GDScript) -> Array[String]:
	var names: Array[String] = []
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with(PREFIX) and not names.has(method_name):
			names.append(method_name)
	return names


func _find_tests() -> Array[String]:
	var found: Array[String] = []
	for root in ROOTS:
		_collect(root, found)
	found.sort()
	return found


func _collect(dir: String, found: Array[String]) -> void:
	var access := DirAccess.open(dir)
	if access == null or access.file_exists(".gdignore"):
		return
	for sub in access.get_directories():
		if not sub.begins_with("."):
			_collect(dir.path_join(sub), found)
	for file in access.get_files():
		if file.begins_with(PREFIX) and file.get_extension() == "gd":
			found.append(dir.path_join(file))
