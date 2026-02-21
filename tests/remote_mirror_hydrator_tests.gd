## RemoteMirrorHydratorTests: Unit tests for remote mirror hydration behavior.

extends RefCounted
class_name RemoteMirrorHydratorTests

const RemoteMirrorHydratorScript = preload("res://scripts/mirror/remote_mirror_hydrator.gd")

func run() -> Dictionary:
	"""Runs RemoteMirrorHydrator unit tests."""
	var results = {"passed": 0, "failed": 0, "failures": []}
	_test_missing_repository_url(results)
	_test_invalid_repository_json(results)
	_test_missing_archive_file(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	"""Records test assertions."""
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_missing_repository_url(results: Dictionary) -> void:
	"""Hydration should fail when repository_url is missing."""
	OfflineEnforcer.reset()
	var hydrator = RemoteMirrorHydratorScript.new("")
	var result = hydrator.hydrate([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(result["success"] == false, "should fail without repository_url", results)

func _test_invalid_repository_json(results: Dictionary) -> void:
	"""Hydration should fail when repository.json is invalid."""
	OfflineEnforcer.reset()
	var temp_root = OS.get_user_data_dir().path_join("remote_repo_invalid")
	if not DirAccess.dir_exists_absolute(temp_root):
		DirAccess.make_dir_recursive_absolute(temp_root)
	var repo_path = temp_root.path_join("repository.json")
	var file = FileAccess.open(repo_path, FileAccess.WRITE)
	if file:
		file.store_string("not-json")
		file.close()

	var hydrator = RemoteMirrorHydratorScript.new(repo_path)
	var result = hydrator.hydrate([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(result["success"] == false, "should fail on invalid repository json", results)

	if FileAccess.file_exists(repo_path):
		DirAccess.remove_absolute(repo_path)
	if DirAccess.dir_exists_absolute(temp_root):
		DirAccess.remove_absolute(temp_root)

func _test_missing_archive_file(results: Dictionary) -> void:
	"""Hydration should fail when archive_url points to a missing local file."""
	OfflineEnforcer.reset()
	var temp_root = OS.get_user_data_dir().path_join("remote_repo_missing_archive")
	if not DirAccess.dir_exists_absolute(temp_root):
		DirAccess.make_dir_recursive_absolute(temp_root)
	var repo_path = temp_root.path_join("repository.json")
	var missing_archive = temp_root.path_join("missing_archive.zip")
	var repo_json = {
		"schema_version": 1,
		"mirror_name": "OGS Remote",
		"tools": [
			{
				"id": "godot",
				"version": "4.3",
				"archive_url": missing_archive,
				"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
			}
		]
	}
	var file = FileAccess.open(repo_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(repo_json))
		file.close()

	var hydrator = RemoteMirrorHydratorScript.new(repo_path)
	var result = hydrator.hydrate([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(result["success"] == false, "should fail when archive file is missing", results)
	_expect(result["failed_count"] == 1, "failed_count should be 1 when archive missing", results)

	if FileAccess.file_exists(repo_path):
		DirAccess.remove_absolute(repo_path)
	if DirAccess.dir_exists_absolute(temp_root):
		DirAccess.remove_absolute(temp_root)
