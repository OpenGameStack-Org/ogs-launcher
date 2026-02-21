## LibraryHydrationControllerTests: Unit tests for mirror-based hydration UI state.

extends RefCounted
class_name LibraryHydrationControllerTests

const LibraryHydrationControllerScript = preload("res://scripts/library/library_hydration_controller.gd")

func run() -> Dictionary:
	"""Runs LibraryHydrationController unit tests."""
	var results = {"passed": 0, "failed": 0, "failures": []}
	_test_blocks_when_mirror_missing(results)
	_test_enables_when_mirror_present(results)
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
	return {
		"dialog": dialog,
		"list": tools_list,
		"status": status_label,
		"button": download_button,
		"nodes": [dialog, tools_list, status_label, download_button]
	}

func _cleanup_nodes(nodes: Array) -> void:
	"""Frees UI nodes created during tests to avoid leaks."""
	for node in nodes:
		if node:
			node.free()

func _write_repository_file(mirror_root: String) -> void:
	"""Writes a minimal valid repository.json file to the mirror root."""
	if not DirAccess.dir_exists_absolute(mirror_root):
		DirAccess.make_dir_recursive_absolute(mirror_root)
	var repo_path = mirror_root.path_join("repository.json")
	var file = FileAccess.open(repo_path, FileAccess.WRITE)
	if file:
		file.store_string("{\"schema_version\":1,\"mirror_name\":\"Test\",\"tools\":[{\"id\":\"godot\",\"version\":\"4.3\",\"archive_path\":\"tools/godot/4.3/godot.zip\",\"sha256\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"}]}")
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
	controller.setup(ui["dialog"], ui["list"], ui["status"], ui["button"], "", null, mirror_root, "")
	controller.start_hydration([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(ui["button"].disabled == true, "button should be disabled when mirror missing", results)
	_expect(ui["status"].text.find("No mirror repository configured") != -1, "status should mention mirror missing", results)
	_cleanup_nodes(ui["nodes"])

func _test_enables_when_mirror_present(results: Dictionary) -> void:
	"""Mirror present should enable download button for missing tools."""
	var ui = _build_ui_nodes()
	var controller = LibraryHydrationControllerScript.new()
	var mirror_root = OS.get_user_data_dir().path_join("mirror_test_present_repo")
	_write_repository_file(mirror_root)
	controller.setup(ui["dialog"], ui["list"], ui["status"], ui["button"], "", null, mirror_root, "")
	controller.start_hydration([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(ui["button"].disabled == false, "button should be enabled when mirror is present", results)
	_expect(ui["status"].text.find("Ready to install") != -1, "status should indicate ready to install", results)
	_cleanup_nodes(ui["nodes"])
	_remove_repository_file(mirror_root)
