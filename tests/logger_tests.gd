## LoggerTests: Unit tests for Logger behavior.

extends RefCounted
class_name LoggerTests

func run() -> Dictionary:
	"""Runs Logger unit tests.
	Returns:
	  Dictionary: {"passed": int, "failed": int, "failures": Array[String]}"""
	var results := {"passed": 0, "failed": 0, "failures": []}
	_test_write_and_level_filter(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	"""Records test assertions.
	Parameters:
	  condition (bool): Pass/fail condition
	  message (String): Failure message
	  results (Dictionary): Aggregated results"""
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_write_and_level_filter(results: Dictionary) -> void:
	"""Verifies log writes and level filtering."""
	Logger.clear_logs_for_tests()
	Logger.set_level(Logger.Level.WARN)
	Logger.info("info message", {"component": "test"})
	Logger.warn("warn message", {"component": "test"})
	var log_path = "user://logs/ogs_launcher.log"
	_expect(FileAccess.file_exists(log_path), "log file should exist", results)
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file:
		var contents = file.get_as_text()
		file.close()
		_expect(contents.find("info message") == -1, "info should be filtered", results)
		_expect(contents.find("warn message") != -1, "warn should be logged", results)
