## MirrorRepositoryTests: Unit tests for MirrorRepository schema validation.

extends RefCounted
class_name MirrorRepositoryTests

const MirrorRepositoryScript = preload("res://scripts/mirror/mirror_repository.gd")

func run() -> Dictionary:
	"""Runs MirrorRepository unit tests."""
	var results = {"passed": 0, "failed": 0, "failures": []}
	_test_valid_repository(results)
	_test_missing_required_fields(results)
	_test_invalid_sha256(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	"""Records test assertions."""
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_valid_repository(results: Dictionary) -> void:
	"""Valid repository should pass validation."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS Standard Profile",
		"tools": [
			{"id": "godot", "version": "4.3", "archive_path": "tools/godot/4.3/godot.zip"}
		]
	}
	var repo = MirrorRepositoryScript.from_dict(data)
	_expect(repo.is_valid(), "valid repository should pass", results)

func _test_missing_required_fields(results: Dictionary) -> void:
	"""Repository missing required fields should fail validation."""
	var data = {"schema_version": 1, "mirror_name": "", "tools": []}
	var errors = MirrorRepositoryScript.validate_data(data)
	_expect(errors.has("mirror_name_empty"), "should flag empty mirror_name", results)
	_expect(errors.has("tools_empty"), "should flag empty tools array", results)

func _test_invalid_sha256(results: Dictionary) -> void:
	"""Invalid sha256 should be rejected when present."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": [
			{"id": "godot", "version": "4.3", "archive_path": "tools/godot/4.3/godot.zip", "sha256": "bad"}
		]
	}
	var errors = MirrorRepositoryScript.validate_data(data)
	_expect(errors.has("tool_sha256_invalid:0"), "should flag invalid sha256", results)
