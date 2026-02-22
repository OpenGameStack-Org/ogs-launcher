## LibraryHydrationControllerTests: Unit tests for mirror-based hydration UI state.

extends RefCounted
class_name LibraryHydrationControllerTests

const LibraryHydrationControllerScript = preload("res://scripts/library/library_hydration_controller.gd")

func run() -> Dictionary:
	"""Runs LibraryHydrationController unit tests."""
	var results = {"passed": 0, "failed": 0, "failures": []}
	_cleanup_library_root()
	_test_blocks_when_mirror_missing(results)
	_test_enables_when_mirror_present(results)
	_test_progress_updates(results)
	_cleanup_library_root()
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	"""Records test assertions."""
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _build_ui_nodes() -> Dictionary:
	"""Creates minimal UI nodes for controller tests."""
	var dialog = PopupPanel.new()
	var tools_list = ItemList.new()
	var status_label = Label.new()
	var download_button = Button.new()
	var close_button = Button.new()
	var progress_dialog = Control.new()  #Simplified for tests
	var progress_status = Label.new()
	var progress_bar = ProgressBar.new()
	var cancel_btn = Button.new()
	var ok_btn = Button.new()
	return {
		"dialog": dialog,
		"list": tools_list,
		"status": status_label,
		"download_btn": download_button,
		"close_btn": close_button,
		"progress_dialog": progress_dialog,
		"progress_status": progress_status,
		"progress_bar": progress_bar,
		"cancel_btn": cancel_btn,
		"ok_btn": ok_btn,
		"nodes": [dialog, tools_list, status_label, download_button, close_button, progress_dialog, progress_status, progress_bar, cancel_btn, ok_btn]
	}

func _cleanup_nodes(nodes: Array) -> void:
	"""Frees UI nodes created during tests to avoid leaks."""
	for node in nodes:
		if node:
			node.free()

func _cleanup_library_root() -> void:
	"""Removes test tool directories from the library to start fresh."""
	var appdata = OS.get_environment("LOCALAPPDATA")
	if appdata.is_empty():
		appdata = OS.get_user_data_dir()
	# Use test-isolated library path set by test_runner
	var library_root = appdata.path_join("OGS_TEST").path_join("Library")
	if DirAccess.dir_exists_absolute(library_root):
		# Remove test tool directories
		for tool_id in ["godot", "blender", "krita", "audacity"]:
			var tool_dir = library_root.path_join(tool_id)
			if DirAccess.dir_exists_absolute(tool_dir):
				_recursive_remove_dir(tool_dir)

func _recursive_remove_dir(path: String) -> void:
	"""Recursively removes a directory and all its contents."""
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				_recursive_remove_dir(full_path)
			else:
				DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
	DirAccess.remove_absolute(path)

func _write_repository_file(mirror_root: String) -> void:
	"""Writes a minimal valid repository.json file to the mirror root."""
	if not DirAccess.dir_exists_absolute(mirror_root):
		DirAccess.make_dir_recursive_absolute(mirror_root)
	var repo_path = mirror_root.path_join("repository.json")
	var repo_data = {
		"schema_version": 1,
		"mirror_name": "Test",
		"tools": [
			{
				"id": "godot",
				"version": "4.3",
				"archive_path": "tools/godot/4.3/godot.zip",
				"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
			}
		]
	}
	var file = FileAccess.open(repo_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(repo_data))
		file.close()

func _remove_repository_file(mirror_root: String) -> void:
	"""Removes repository.json and mirror root for test cleanup."""
	var repo_path = mirror_root.path_join("repository.json")
	if FileAccess.file_exists(repo_path):
		DirAccess.remove_absolute(repo_path)
	if DirAccess.dir_exists_absolute(mirror_root):
		DirAccess.remove_absolute(mirror_root)

func _test_blocks_when_mirror_missing(results: Dictionary) -> void:
	"""Mirror missing should disable download button and show error status."""
	var ui = _build_ui_nodes()
	var controller = LibraryHydrationControllerScript.new()
	var mirror_root = OS.get_user_data_dir().path_join("mirror_test_missing_repo")
	_remove_repository_file(mirror_root)
	controller.setup(ui["dialog"], ui["list"], ui["status"], ui["download_btn"], ui["close_btn"], ui["progress_dialog"], ui["progress_status"], ui["progress_bar"], ui["cancel_btn"], ui["ok_btn"], "", null, mirror_root, "")
	controller.start_hydration([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(ui["download_btn"].disabled == true, "button should be disabled when mirror missing", results)
	_expect(ui["status"].text.find("No mirror repository configured") != -1, "status should mention mirror missing", results)
	_cleanup_nodes(ui["nodes"])

func _test_enables_when_mirror_present(results: Dictionary) -> void:
	"""Mirror present should enable download button for missing tools."""
	var ui = _build_ui_nodes()
	var controller = LibraryHydrationControllerScript.new()
	var mirror_root = OS.get_user_data_dir().path_join("mirror_test_present_repo")
	_write_repository_file(mirror_root)
	controller.setup(ui["dialog"], ui["list"], ui["status"], ui["download_btn"], ui["close_btn"], ui["progress_dialog"], ui["progress_status"], ui["progress_bar"], ui["cancel_btn"], ui["ok_btn"], "", null, mirror_root, "")
	controller.start_hydration([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(ui["download_btn"].disabled == false, "button should be enabled when mirror is present", results)
	_expect(ui["status"].text.find("Ready to install") != -1, "status should indicate ready to install", results)
	_cleanup_nodes(ui["nodes"])
	_remove_repository_file(mirror_root)

func _test_progress_updates(results: Dictionary) -> void:
	"""Progress bar should advance when tool installs complete."""
	var ui = _build_ui_nodes()
	var controller = LibraryHydrationControllerScript.new()
	controller.setup(ui["dialog"], ui["list"], ui["status"], ui["download_btn"], ui["close_btn"], ui["progress_dialog"], ui["progress_status"], ui["progress_bar"], ui["cancel_btn"], ui["ok_btn"], "", null, "", "")
	controller.active_tool_total = 2
	controller.active_tool_completed = 0
	controller.progress_progress_bar = ui["progress_bar"]
	controller.progress_progress_bar.min_value = 0
	controller.progress_progress_bar.max_value = 2
	controller.progress_progress_bar.value = 0
	
	controller._on_tool_install_complete("godot", "4.3", true, "")
	_expect(int(ui["progress_bar"].value) == 1, "progress bar should advance to 1 after first tool", results)
	controller._on_tool_install_complete("blender", "4.5.7", true, "")
	_expect(int(ui["progress_bar"].value) == 2, "progress bar should advance to 2 after second tool", results)
	_cleanup_nodes(ui["nodes"])
