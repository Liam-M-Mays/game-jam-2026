class_name GameTest
extends RefCounted
## The base of every test script.
##
## A test script is a file named [code]test_<something>.gd[/code] in a
## [code]tests/[/code] folder under [code]assets/Scripts/[/code], next to the
## code it tests. It extends this class. Every method whose name starts with
## [code]test_[/code] is one test, and each test runs on a fresh copy of the
## script. Run them with [code]bash .github/ci/run_tests.sh[/code].

## The scene tree, for the few tests that need a node or a frame.
var tree: SceneTree

var _checks := 0
var _failures: Array[String] = []


## Runs before each test. Override it to build what every test needs.
func before_each() -> void:
	pass


## Runs after each test. Override it to free what [method before_each] built.
func after_each() -> void:
	pass


## Passes when [param condition] is true.
func check(condition: bool, message: String = "") -> void:
	_checks += 1
	if not condition:
		_failures.append(message if message != "" else "a check was false")


## Passes when [param got] equals [param want].
func check_eq(got: Variant, want: Variant, message: String = "") -> void:
	_checks += 1
	if typeof(got) != typeof(want) or got != want:
		_failures.append("%sgot %s, want %s" % [_lead(message), var_to_str(got), var_to_str(want)])


## Passes when [param got] is within [param tolerance] of [param want].
func check_near(got: float, want: float, tolerance: float = 0.0001, message: String = "") -> void:
	_checks += 1
	if absf(got - want) > tolerance:
		_failures.append("%sgot %s, want %s give or take %s" % [_lead(message), got, want, tolerance])


## Fails the test with [param message].
func fail(message: String) -> void:
	_checks += 1
	_failures.append(message)


## How many checks this test has run. The runner fails a test that ran none.
func check_count() -> int:
	return _checks


## What went wrong in this test, one line per failed check.
func failures() -> Array[String]:
	return _failures


func _lead(message: String) -> String:
	return "" if message == "" else message + ": "
