## TestRunner: Headless Test Execution Entry Point
##
## Loads all test suites, aggregates results, and exits with status code:
##   0 = All tests passed
##   1 = One or more tests failed
##
## Usage:
##   godot --headless --script res://tests/test_runner.gd

extends SceneTree

var should_quit := false
var exit_code := 0

func _init() -> void:
	"""Initializes the test runner."""
	# Schedule the actual tests to run in _process on the next frame
	pass

func _process(_delta: float) -> bool:
	"""Called once per frame. Runs tests on first frame."""
	if should_quit:
		return true
	
	should_quit = true
	print("TestRunner: Starting test execution...")
	
	# Pre-load classes to register class_name
	load("res://scripts/config/ogs_config.gd")
	load("res://scripts/manifest/stack_manifest.gd")
	load("res://scripts/manifest/stack_generator.gd")
	load("res://scripts/projects/projects_controller.gd")
	load("res://scripts/projects/project_environment_validator.gd")
	load("res://scripts/projects/project_sealer.gd")
	load("res://scripts/launcher/tool_launcher.gd")
	load("res://scripts/launcher/tool_config_injector.gd")
	load("res://scripts/logging/logger.gd")
	load("res://scripts/network/offline_enforcer.gd")
	load("res://scripts/network/socket_blocker.gd")
	load("res://scripts/network/tool_downloader.gd")
	load("res://scripts/library/path_resolver.gd")
	load("res://scripts/library/library_manager.gd")
	load("res://scripts/library/tool_extractor.gd")
	load("res://scripts/library/library_hydrator.gd")
	load("res://scripts/mirror/mirror_repository.gd")
	load("res://scripts/mirror/mirror_path_resolver.gd")
	load("res://scripts/mirror/mirror_hydrator.gd")
	load("res://scripts/library/library_hydration_controller.gd")
	load("res://scripts/onboarding/onboarding_wizard.gd")
	
	var summary := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	# Instantiate test suites dynamically
	var test_suites: Array = []
	var test_files = [
		"res://tests/stack_manifest_tests.gd",
		"res://tests/ogs_config_tests.gd",
		"res://tests/stack_generator_tests.gd",
		"res://tests/projects_controller_scene_tests.gd",
		"res://tests/main_scene_tests.gd",
		"res://tests/tool_launcher_tests.gd",
		"res://tests/offline_enforcer_tests.gd",
		"res://tests/tool_downloader_tests.gd",
		"res://tests/tool_config_injector_tests.gd",
		"res://tests/socket_blocker_tests.gd",
		"res://tests/logger_tests.gd",
		"res://tests/path_resolver_tests.gd",
		"res://tests/library_manager_tests.gd",
		"res://tests/tool_extractor_tests.gd",
		"res://tests/project_environment_validator_tests.gd",
		"res://tests/library_hydrator_tests.gd",
		"res://tests/library_hydration_controller_tests.gd",
		"res://tests/project_sealer_tests.gd",
		"res://tests/mirror_repository_tests.gd",
		"res://tests/mirror_path_resolver_tests.gd",
		"res://tests/mirror_hydrator_tests.gd",
		"res://tests/startup_tests.gd",
	]
	
	for test_file in test_files:
		var test_class = load(test_file)
		if test_class:
			test_suites.append(test_class.new())
	
	print("TestRunner: Running %d test suites..." % test_suites.size())
	
	# Run all tests
	for suite in test_suites:
		var result = suite.run()
		summary["passed"] += result["passed"]
		summary["failed"] += result["failed"]
		summary["failures"].append_array(result["failures"])
	
	# Print summary
	print("tests passed: %d" % summary["passed"])
	print("tests failed: %d" % summary["failed"])
	if summary["failed"] > 0:
		for failure in summary["failures"]:
			printerr("failure: %s" % failure)
	
	# Exit with appropriate code
	exit_code = 1 if summary["failed"] > 0 else 0
	print("TestRunner: Tests complete, exiting with code %d" % exit_code)
	
	# Exit on the next frame
	quit(exit_code)
	return true
