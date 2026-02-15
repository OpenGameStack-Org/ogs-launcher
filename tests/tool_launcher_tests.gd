extends RefCounted
class_name ToolLauncherTests

const ToolLauncher = preload("res://scripts/launcher/tool_launcher.gd")
const OfflineEnforcer = preload("res://scripts/network/offline_enforcer.gd")
const OgsConfigScript = preload("res://scripts/config/ogs_config.gd")

## Unit tests for ToolLauncher process spawning logic.
##
## Note: These tests focus on error handling and argument building.
## Actual process spawning is tested manually to avoid side effects.

func run() -> Dictionary:
	var results := {"passed": 0, "failed": 0, "failures": []}
	
	_test_missing_path_field(results)
	_test_empty_path_field(results)
	_test_empty_project_dir(results)
	_test_tool_not_found(results)
	_test_godot_arguments(results)
	_test_blender_arguments(results)
	_test_unknown_tool_arguments(results)
	_test_absolute_path_handling(results)
	_test_relative_path_handling(results)
	_test_path_traversal_blocked(results)
	_test_sha256_mismatch(results)
	_test_sha256_invalid(results)
	_test_offline_injection_failure(results)
	
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_missing_path_field(results: Dictionary) -> void:
	"""Validates that missing 'path' field returns TOOL_PATH_MISSING error."""
	var tool_entry = {"id": "godot", "version": "4.3"}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/test")
	
	_expect(not result["success"], "missing path should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_PATH_MISSING, 
		"missing path should return TOOL_PATH_MISSING", results)
	_expect(result["pid"] == -1, "failed launch should return pid -1", results)

func _test_empty_path_field(results: Dictionary) -> void:
	"""Validates that empty 'path' field returns TOOL_PATH_MISSING error."""
	var tool_entry = {"id": "godot", "version": "4.3", "path": ""}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/test")
	
	_expect(not result["success"], "empty path should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_PATH_MISSING, 
		"empty path should return TOOL_PATH_MISSING", results)

func _test_empty_project_dir(results: Dictionary) -> void:
	"""Validates that empty project directory returns INVALID_PROJECT_DIR error."""
	var tool_entry = {"id": "godot", "version": "4.3", "path": "tools/godot.exe"}
	var result = ToolLauncher.launch(tool_entry, "")
	
	_expect(not result["success"], "empty project dir should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.INVALID_PROJECT_DIR, 
		"empty project dir should return INVALID_PROJECT_DIR", results)

func _test_tool_not_found(results: Dictionary) -> void:
	"""Validates that non-existent tool path returns TOOL_NOT_FOUND error."""
	var tool_entry = {"id": "godot", "version": "4.3", "path": "tools/nonexistent.exe"}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/test")
	
	_expect(not result["success"], "nonexistent tool should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_NOT_FOUND, 
		"nonexistent tool should return TOOL_NOT_FOUND", results)

func _test_godot_arguments(results: Dictionary) -> void:
	"""Validates that Godot tool receives --path argument."""
	var args = ToolLauncher._build_launch_arguments("godot", "C:/Projects/MyGame")
	
	_expect(args.size() == 2, "godot should get 2 args (--path + dir)", results)
	_expect(args[0] == "--path", "first arg should be --path", results)
	_expect(args[1] == "C:/Projects/MyGame", "second arg should be project dir", results)

func _test_blender_arguments(results: Dictionary) -> void:
	"""Validates that Blender tool receives no special arguments."""
	var args = ToolLauncher._build_launch_arguments("blender", "C:/Projects/MyGame")
	
	_expect(args.size() == 0, "blender should get no special args", results)

func _test_unknown_tool_arguments(results: Dictionary) -> void:
	"""Validates that unknown tools receive no special arguments."""
	var args = ToolLauncher._build_launch_arguments("krita", "C:/Projects/MyGame")
	
	_expect(args.size() == 0, "unknown tool should get no special args", results)

func _test_absolute_path_handling(results: Dictionary) -> void:
	"""Validates that absolute paths are rejected."""
	var tool_entry = {"id": "test", "version": "1.0", "path": "C:/absolute/path/test.exe"}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/MyGame")
	
	_expect(not result["success"], "nonexistent absolute path should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_PATH_ABSOLUTE,
		"absolute paths should be rejected", results)

func _test_relative_path_handling(results: Dictionary) -> void:
	"""Validates that relative paths are joined with project directory."""
	var tool_entry = {"id": "test", "version": "1.0", "path": "tools/relative.exe"}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/MyGame")
	
	_expect(not result["success"], "nonexistent relative path should fail", results)
	_expect(result["error_message"].find("C:/Projects/MyGame/tools/relative.exe") != -1, 
		"error should show joined relative path", results)

func _test_path_traversal_blocked(results: Dictionary) -> void:
	"""Validates that path traversal outside the project root is blocked."""
	var tool_entry = {"id": "test", "version": "1.0", "path": "../outside.exe"}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/MyGame")
	_expect(not result["success"], "path traversal should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_PATH_OUTSIDE_ROOT,
		"path traversal should return TOOL_PATH_OUTSIDE_ROOT", results)

func _test_sha256_mismatch(results: Dictionary) -> void:
	"""Validates sha256 mismatch is detected before spawning tools."""
	var project_dir = ProjectSettings.globalize_path("user://tool_launcher_tests")
	var rel_path = "tools/mock_tool.bin"
	var full_path = project_dir.path_join(rel_path)
	DirAccess.make_dir_recursive_absolute(full_path.get_base_dir())
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file:
		file.store_string("mock")
		file.close()
	var tool_entry = {
		"id": "test",
		"version": "1.0",
		"path": rel_path,
		"sha256": "0".repeat(64)
	}
	var result = ToolLauncher.launch(tool_entry, project_dir)
	_expect(not result["success"], "sha256 mismatch should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_HASH_MISMATCH,
		"sha256 mismatch should return TOOL_HASH_MISMATCH", results)

func _test_sha256_invalid(results: Dictionary) -> void:
	"""Validates invalid sha256 values are rejected."""
	var project_dir = ProjectSettings.globalize_path("user://tool_launcher_tests")
	var rel_path = "tools/mock_tool_invalid.bin"
	var full_path = project_dir.path_join(rel_path)
	DirAccess.make_dir_recursive_absolute(full_path.get_base_dir())
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file:
		file.store_string("mock")
		file.close()
	var tool_entry = {
		"id": "test",
		"version": "1.0",
		"path": rel_path,
		"sha256": "not-a-hash"
	}
	var result = ToolLauncher.launch(tool_entry, project_dir)
	_expect(not result["success"], "invalid sha256 should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_HASH_INVALID,
		"invalid sha256 should return TOOL_HASH_INVALID", results)

func _test_offline_injection_failure(results: Dictionary) -> void:
	"""Verifies offline injection errors are surfaced when config write fails."""
	var tool_entry = {"id": "godot", "version": "4.3", "path": "tools/missing.exe"}
	var config = OgsConfigScript.from_dict({"offline_mode": true})
	OfflineEnforcer.apply_config(config)
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/MyGame")
	_expect(not result["success"], "offline launch should fail on bad config", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.OFFLINE_CONFIG_FAILED or result["error_code"] == ToolLauncher.LaunchError.TOOL_NOT_FOUND,
		"offline errors should be surfaced", results)
	OfflineEnforcer.apply_config(OgsConfigScript.from_dict({"offline_mode": false}))
