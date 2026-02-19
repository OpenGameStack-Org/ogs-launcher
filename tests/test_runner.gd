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
	load("res://scripts/launcher/tool_config_injector.gd")
	load("res://scripts/logging/logger.gd")
	load("res://scripts/network/offline_enforcer.gd")
	load("res://scripts/network/socket_blocker.gd")
	load("res://scripts/network/tool_downloader.gd")
	load("res://scripts/library/path_resolver.gd")
	load("res://scripts/library/library_manager.gd")
	load("res://scripts/library/tool_extractor.gd")
	
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
	var offline_enforcer_tests = load("res://tests/offline_enforcer_tests.gd")
	if offline_enforcer_tests:
		test_suites.append(offline_enforcer_tests.new())
	var tool_downloader_tests = load("res://tests/tool_downloader_tests.gd")
	if tool_downloader_tests:
		test_suites.append(tool_downloader_tests.new())
	var tool_config_injector_tests = load("res://tests/tool_config_injector_tests.gd")
	if tool_config_injector_tests:
		test_suites.append(tool_config_injector_tests.new())
	var socket_blocker_tests = load("res://tests/socket_blocker_tests.gd")
	if socket_blocker_tests:
		test_suites.append(socket_blocker_tests.new())
	var logger_tests = load("res://tests/logger_tests.gd")
	if logger_tests:
		test_suites.append(logger_tests.new())
	var path_resolver_tests = load("res://tests/path_resolver_tests.gd")
	if path_resolver_tests:
		test_suites.append(path_resolver_tests.new())
	var library_manager_tests = load("res://tests/library_manager_tests.gd")
	if library_manager_tests:
		test_suites.append(library_manager_tests.new())
	var tool_extractor_tests = load("res://tests/tool_extractor_tests.gd")
	if tool_extractor_tests:
		test_suites.append(tool_extractor_tests.new())
	
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
