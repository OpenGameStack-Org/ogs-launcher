## TestRunner: Headless Test Execution Entry Point
##
## Loads all test suites, aggregates results, and exits with status code:
##   0 = All tests passed
##   1 = One or more tests failed
##
## Usage:
##   godot --headless --script res://tests/test_runner.gd
##
## The runner dynamically loads test suites to avoid hard script dependencies
## that may cause issues in headless mode.

extends SceneTree

## Entry point for headless test execution.
## Invoked automatically when Godot starts in headless mode.
## Loads test suites, runs them, aggregates results, and exits.
func _init() -> void:
	"""Entry point for headless test execution."""
	var summary := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	# Instantiate test suites dynamically
	var test_suites: Array = []
	var test_script = load("res://tests/stack_manifest_tests.gd")
	if test_script:
		test_suites.append(test_script.new())
	
	for suite in test_suites:
		var result = suite.run()
		summary["passed"] += result["passed"]
		summary["failed"] += result["failed"]
		summary["failures"].append_array(result["failures"])
	_print_summary(summary)
	if summary["failed"] > 0:
		quit(1)
	else:
		quit(0)

## Prints a human-readable test summary to stdout and stderr.
## Displays passed/failed counts, and lists all failures if any.
## Parameters:
##   summary (Dictionary): Test results {"passed": int, "failed": int, "failures": Array[String]}
func _print_summary(summary: Dictionary) -> void:
	"""Prints a human-readable summary of test results."""
	print("tests passed: %d" % summary["passed"])
	print("tests failed: %d" % summary["failed"])
	if summary["failed"] > 0:
		for failure in summary["failures"]:
			printerr("failure: %s" % failure)
