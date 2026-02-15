## ToolDownloader: Guarded entry point for future tool downloads.
##
## Provides an offline-safe download interface that blocks network access when
## offline mode is active. Actual download implementation will be added in
## Phase 2, but the guardrails exist now to enforce air-gap behavior.

extends RefCounted
class_name ToolDownloader

const OfflineEnforcer = preload("res://scripts/network/offline_enforcer.gd")

## Error codes for download failures.
enum DownloadError {
	SUCCESS = 0,
	OFFLINE_BLOCKED = 1,
	NOT_IMPLEMENTED = 2,
}

static func download_tool(tool_id: String, version: String, target_path: String) -> Dictionary:
	"""Attempts to download a tool to the target path.
	Parameters:
	  tool_id (String): Tool identifier (e.g., "godot")
	  version (String): Version string (e.g., "4.3")
	  target_path (String): Destination path
	Returns:
	  Dictionary: {"success": bool, "error_code": int, "error_message": String}
	"""
	var guard = OfflineEnforcer.guard_network_call("download_tool:%s" % tool_id)
	if not guard["allowed"]:
		return {
			"success": false,
			"error_code": DownloadError.OFFLINE_BLOCKED,
			"error_message": guard["error_message"]
		}
	return {
		"success": false,
		"error_code": DownloadError.NOT_IMPLEMENTED,
		"error_message": "Download not implemented yet for %s %s" % [tool_id, version]
	}
