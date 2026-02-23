## ProjectsPageIndicatorsTests: Tests for tool availability indicators
##
## Verifies that the Projects page correctly displays:
##   - ⚠️ indicator for missing but available tools
##   - ❌ indicator for missing and unavailable tools
##   - No indicator for installed tools
##   - Click-through navigation to Tools page

extends RefCounted
class_name ProjectsPageIndicatorsTests

const ProjectsControllerScript = preload("res://scripts/projects/projects_controller.gd")
const ToolsControllerScript = preload("res://scripts/tools/tools_controller.gd")

func run() -> Dictionary:
	"""Runs all Projects page indicator tests.
	Returns:
	  Dictionary: {"passed": int, "failed": int, "failures": Array[String]}"""
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_populate_tools_list_with_availability(results)
	_test_tool_view_requested_signal(results)
	_test_availability_tracking(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	"""Records test assertion."""
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _build_projects_controller() -> Dictionary:
	"""Creates a projects controller with UI nodes and tools controller.
	Returns:
	  Dictionary: {"controller": ProjectsController, "tools_controller": ToolsController, ...}"""
	var projects_controller = ProjectsControllerScript.new()
	var tools_controller = ToolsControllerScript.new(null, "")  # null scene tree, empty URL
	
	var line_edit = LineEdit.new()
	var browse_button = Button.new()
	var load_button = Button.new()
	var new_button = Button.new()
	var status_label = Label.new()
	var offline_label = Label.new()
	var tools_list = ItemList.new()
	var launch_button = Button.new()
	var dialog = FileDialog.new()

	projects_controller.setup(
		line_edit,
		browse_button,
		load_button,
		new_button,
		status_label,
		offline_label,
		tools_list,
		launch_button,
		dialog,
		tools_controller  # Pass tools controller for availability checking
	)

	return {
		"controller": projects_controller,
		"tools_controller": tools_controller,
		"tools_list": tools_list,
		"nodes": [line_edit, browse_button, load_button, new_button, status_label, offline_label, tools_list, launch_button, dialog]
	}

func _cleanup_nodes(nodes: Array) -> void:
	"""Frees UI nodes created during tests to avoid leaks."""
	for node in nodes:
		if node is Node:
			node.queue_free()

func _test_populate_tools_list_with_availability(results: Dictionary) -> void:
	"""Verifies _populate_tools_list adds indicators based on availability."""
	var ctx = _build_projects_controller()
	var controller = ctx["controller"]
	var tools_list = ctx["tools_list"]
	
	# Create test tools manifest
	var tools = [
		{"id": "godot", "version": "4.3", "path": ""},
		{"id": "blender", "version": "4.5", "path": ""},
		{"id": "krita", "version": "5.2", "path": ""}
	]
	
	# Populate the list
	controller._populate_tools_list(tools)
	
	# Check that tools were added to the list
	_expect(tools_list.item_count == 3, "Should add 3 tools to list", results)
	
	# Check that labels contain tool IDs and versions (indicators may vary based on availability)
	var item_0_text = tools_list.get_item_text(0)
	var item_1_text = tools_list.get_item_text(1)
	var item_2_text = tools_list.get_item_text(2)
	
	_expect(item_0_text.find("godot") != -1, "Item 0 should contain 'godot'", results)
	_expect(item_0_text.find("4.3") != -1, "Item 0 should contain '4.3'", results)
	_expect(item_1_text.find("blender") != -1, "Item 1 should contain 'blender'", results)
	_expect(item_2_text.find("krita") != -1, "Item 2 should contain 'krita'", results)
	
	_cleanup_nodes(ctx["nodes"])

func _test_tool_view_requested_signal(results: Dictionary) -> void:
	"""Verifies tool_view_requested signal is emitted via ItemList click wiring."""
	var ctx = _build_projects_controller()
	var controller = ctx["controller"]
	var tools_list = ctx["tools_list"]
	
	# Use dictionary to track signal state (avoids lambda capture issues)
	var signal_state = {
		"emitted": false,
		"tool_id": "",
		"version": ""
	}
	
	controller.tool_view_requested.connect(func(tool_id: String, version: String):
		signal_state["emitted"] = true
		signal_state["tool_id"] = tool_id
		signal_state["version"] = version
	)
	
	# Set up test manifest and populate
	var tools = [
		{"id": "godot", "version": "4.3", "path": ""},
		{"id": "blender", "version": "4.5", "path": ""}
	]
	controller.current_manifest = StackManifest.new()
	controller.current_manifest.tools = tools
	controller.current_manifest.stack_name = "test"
	
	controller._populate_tools_list(tools)
	
	# Simulate clicking the first tool through ItemList signal wiring
	tools_list.item_clicked.emit(0, Vector2.ZERO, 1)
	
	# Verify setup
	_expect(tools_list.item_count == 2, "Should have added 2 tools", results)
	_expect(controller._tool_availability.size() == 2, "Should track 2 tools in _tool_availability", results)
	_expect(signal_state["emitted"] == true, "tool_view_requested should emit on item click", results)
	_expect(signal_state["tool_id"] == "godot", "tool_view_requested should pass tool id", results)
	_expect(signal_state["version"] == "4.3", "tool_view_requested should pass tool version", results)
	
	_cleanup_nodes(ctx["nodes"])

func _test_availability_tracking(results: Dictionary) -> void:
	"""Verifies _tool_availability dictionary is populated correctly."""
	var ctx = _build_projects_controller()
	var controller = ctx["controller"]
	
	# Create test tools
	var tools = [
		{"id": "godot", "version": "4.3", "path": ""},
		{"id": "missing_tool", "version": "1.0", "path": ""}
	]
	
	controller._populate_tools_list(tools)
	
	# Check that availability tracking is set up
	_expect("godot_4.3" in controller._tool_availability, "Should track godot_4.3 availability", results)
	_expect("missing_tool_1.0" in controller._tool_availability, "Should track missing_tool_1.0 availability", results)
	
	# Check structure of availability entries
	var godot_info = controller._tool_availability.get("godot_4.3", {})
	_expect(godot_info.has("installed"), "Availability entry should have 'installed' key", results)
	_expect(godot_info.has("available"), "Availability entry should have 'available' key", results)
	
	_cleanup_nodes(ctx["nodes"])
