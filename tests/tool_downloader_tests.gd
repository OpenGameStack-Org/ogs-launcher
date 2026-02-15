## ToolDownloaderTests: Unit tests for ToolDownloader guard behavior.

extends RefCounted
class_name ToolDownloaderTests

const ToolDownloader = preload("res://scripts/network/tool_downloader.gd")
const OfflineEnforcer = preload("res://scripts/network/offline_enforcer.gd")
const OgsConfigScript = preload("res://scripts/config/ogs_config.gd")

func run() -> Dictionary:
	"""Runs ToolDownloader unit tests.
	Returns:
	  Dictionary: {"passed": int, "failed": int, "failures": Array[String]}"""
	var results := {"passed": 0, "failed": 0, "failures": []}
	_test_offline_blocks(results)
	_test_online_not_implemented(results)
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

func _test_offline_blocks(results: Dictionary) -> void:
	"""Verifies offline mode blocks download attempts."""
	OfflineEnforcer.reset()
	var config = OgsConfigScript.from_dict({"offline_mode": true})
	OfflineEnforcer.apply_config(config)
	var result = ToolDownloader.download_tool("godot", "4.3", "res://tools/godot.exe")
	_expect(not result["success"], "offline download should fail", results)
	_expect(result["error_code"] == ToolDownloader.DownloadError.OFFLINE_BLOCKED, "offline error code should be OFFLINE_BLOCKED", results)

func _test_online_not_implemented(results: Dictionary) -> void:
	"""Verifies online mode returns NOT_IMPLEMENTED for now."""
	OfflineEnforcer.reset()
	var config = OgsConfigScript.from_dict({"offline_mode": false})
	OfflineEnforcer.apply_config(config)
	var result = ToolDownloader.download_tool("godot", "4.3", "res://tools/godot.exe")
	_expect(not result["success"], "online download should still fail", results)
	_expect(result["error_code"] == ToolDownloader.DownloadError.NOT_IMPLEMENTED, "online error code should be NOT_IMPLEMENTED", results)
