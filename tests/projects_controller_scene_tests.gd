## ProjectsControllerSceneTests: Scene-style tests for ProjectsController
##
## Verifies UI interactions and project loading behaviors with real UI nodes:
##   - Empty path prompts selection
##   - Missing stack.json returns error status and clears list
##   - Valid sample project populates list and offline label

extends RefCounted
class_name ProjectsControllerSceneTests

const ProjectsControllerScript = preload("res://scripts/projects/projects_controller.gd")

func run() -> Dictionary:
	"""Runs all ProjectsController scene tests.
	Returns:
	  Dictionary: {"passed": int, "failed": int, "failures": Array[String]}"""
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_empty_path(results)
	_test_missing_stack(results)
	_test_valid_sample_project(results)
	_test_launch_button_disabled_initially(results)
	_test_launch_button_enabled_after_load(results)
	_test_launch_no_selection(results)
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

func _build_controller() -> Dictionary:
	"""Creates a controller with UI nodes wired for testing.
	Returns:
	  Dictionary: {"controller": ProjectsController, "status": Label, "offline": Label, "list": ItemList, "launch_btn": Button}"""
	var controller = ProjectsControllerScript.new()
	var line_edit = LineEdit.new()
	var browse_button = Button.new()
	var load_button = Button.new()
	var new_button = Button.new()
	var status_label = Label.new()
	var offline_label = Label.new()
	var tools_list = ItemList.new()
	var launch_button = Button.new()
	var dialog = FileDialog.new()

	controller.setup(
		line_edit,
		browse_button,
		load_button,
		new_button,
		status_label,
		offline_label,
		tools_list,
		launch_button,
		dialog
	)

	return {
		"controller": controller,
		"status": status_label,
		"offline": offline_label,
		"list": tools_list,
		"launch_btn": launch_button,
		"nodes": [line_edit, browse_button, load_button, new_button, status_label, offline_label, tools_list, launch_button, dialog]
	}

func _cleanup_nodes(nodes: Array) -> void:
	"""Frees UI nodes created during tests to avoid leaks."""
	for node in nodes:
		if node:
			node.free()

func _test_empty_path(results: Dictionary) -> void:
	"""Verifies empty path prompts selection message."""
	var ctx = _build_controller()
	var controller = ctx["controller"]
	controller._load_project_from_path("")
	var status_label: Label = ctx["status"]
	_expect(status_label.text.find("Please select") != -1, "empty path should prompt selection", results)
	_cleanup_nodes(ctx["nodes"])

func _test_missing_stack(results: Dictionary) -> void:
	"""Verifies missing stack.json shows error and clears list."""
	var ctx = _build_controller()
	var controller = ctx["controller"]
	controller._load_project_from_path("res://samples/does_not_exist")
	var status_label: Label = ctx["status"]
	var offline_label: Label = ctx["offline"]
	var tools_list: ItemList = ctx["list"]
	_expect(status_label.text.find("stack.json not found") != -1, "missing stack.json should error", results)
	_expect(offline_label.text.find("Unknown") != -1, "missing stack.json should set offline unknown", results)
	_expect(tools_list.item_count == 0, "missing stack.json should clear tools list", results)
	_cleanup_nodes(ctx["nodes"])

func _test_valid_sample_project(results: Dictionary) -> void:
	"""Verifies sample project loads and populates the tools list."""
	var ctx = _build_controller()
	var controller = ctx["controller"]
	controller._load_project_from_path("res://samples/sample_project")
	var status_label: Label = ctx["status"]
	var offline_label: Label = ctx["offline"]
	var tools_list: ItemList = ctx["list"]
	_expect(status_label.text.find("Manifest loaded") != -1, "valid project should load manifest", results)
	_expect(offline_label.text.find("Disabled") != -1, "sample config should be offline disabled", results)
	_expect(tools_list.item_count >= 1, "valid project should populate tools list", results)
	_cleanup_nodes(ctx["nodes"])

func _test_launch_button_disabled_initially(results: Dictionary) -> void:
	"""Verifies launch button starts disabled."""
	var ctx = _build_controller()
	var launch_btn: Button = ctx["launch_btn"]
	_expect(launch_btn.disabled == true, "launch button should be disabled initially", results)
	_cleanup_nodes(ctx["nodes"])

func _test_launch_button_enabled_after_load(results: Dictionary) -> void:
	"""Verifies launch button is enabled after loading valid project."""
	var ctx = _build_controller()
	var controller = ctx["controller"]
	var launch_btn: Button = ctx["launch_btn"]
	controller._load_project_from_path("res://samples/sample_project")
	_expect(launch_btn.disabled == false, "launch button should be enabled after valid load", results)
	_cleanup_nodes(ctx["nodes"])

func _test_launch_no_selection(results: Dictionary) -> void:
	"""Verifies launching with no tool selected shows error."""
	var ctx = _build_controller()
	var controller = ctx["controller"]
	var status_label: Label = ctx["status"]
	controller._load_project_from_path("res://samples/sample_project")
	controller._on_launch_tool_pressed()
	_expect(status_label.text.find("No tool selected") != -1, "launch with no selection should error", results)
	_cleanup_nodes(ctx["nodes"])
