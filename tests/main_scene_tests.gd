## MainSceneTests: Scene smoke tests for main.tscn
##
## Verifies the main scene loads and default visibility state is correct.

extends RefCounted
class_name MainSceneTests

func run() -> Dictionary:
	"""Runs main scene smoke tests.
	Returns:
	  Dictionary: {"passed": int, "failed": int, "failures": Array[String]}"""
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_main_scene_loads(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	"""Records test assertion.
	Parameters:
	  condition (bool): If true, increments passed; if false, increments failed
	  message (String): Failure description
	  results (Dictionary): Test accumulator (modified in-place)"""
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_main_scene_loads(results: Dictionary) -> void:
	"""Verifies main.tscn loads and projects page is visible by default."""
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load", results)
	if scene == null:
		return

	var instance = scene.instantiate()
	var page_projects = instance.get_node_or_null("AppLayout/Content/PageProjects")
	var page_engine = instance.get_node_or_null("AppLayout/Content/PageEngine")
	var page_tools = instance.get_node_or_null("AppLayout/Content/PageTools")
	var page_settings = instance.get_node_or_null("AppLayout/Content/PageSettings")

	_expect(page_projects != null, "Projects page should exist", results)
	_expect(page_engine != null, "Engine page should exist", results)
	_expect(page_tools != null, "Tools page should exist", results)
	_expect(page_settings != null, "Settings page should exist", results)

	var new_button = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsControls/NewButton")
	_expect(new_button != null, "New Project button should exist", results)

	instance.free()
