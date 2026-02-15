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
	# Pre-load classes to register class_name
	load("res://scripts/config/ogs_config.gd")
	load("res://scripts/manifest/stack_manifest.gd")
	load("res://scripts/manifest/stack_generator.gd")
	load("res://scripts/projects/projects_controller.gd")
	load("res://scripts/launcher/tool_launcher.gd")
	
	var summary := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	# Instantiate test suites dynamically
	var test_suites: Array = []
	var stack_manifest_tests = load("res://tests/stack_manifest_tests.gd")
	if stack_manifest_tests:
		test_suites.append(stack_manifest_tests.new())
	var ogs_config_tests = load("res://tests/ogs_config_tests.gd")
	if ogs_config_tests:
		test_suites.append(ogs_config_tests.new())
	var stack_generator_tests = load("res://tests/stack_generator_tests.gd")
	if stack_generator_tests:
		test_suites.append(stack_generator_tests.new())
	var projects_controller_scene_tests = load("res://tests/projects_controller_scene_tests.gd")
	if projects_controller_scene_tests:
		test_suites.append(projects_controller_scene_tests.new())
	var main_scene_tests = load("res://tests/main_scene_tests.gd")
	if main_scene_tests:
		test_suites.append(main_scene_tests.new())
	var tool_launcher_tests = load("res://tests/tool_launcher_tests.gd")
	if tool_launcher_tests:
		test_suites.append(tool_launcher_tests.new())
	
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
