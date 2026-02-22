## ToolLauncher: Responsible for launching tools from the frozen stack.
##
## Applies tool-specific arguments, offline injection overrides, and returns
## structured error details for UI-friendly reporting.

extends RefCounted
class_name ToolLauncher

## Handles spawning external tools from the frozen stack with correct environment and working directory.
##
## This class is responsible for:
## - Resolving tool paths relative to the project directory
## - Rejecting absolute or project-escaping tool paths
## - Enforcing optional sha256 verification when provided
## - Building tool-specific launch arguments (e.g., Godot's --path flag)
## - Spawning processes in a way that respects air-gap constraints
## - Returning detailed error information for troubleshooting

## Error codes for launch failures
enum LaunchError {
	SUCCESS = 0,
	TOOL_PATH_MISSING = 1,   ## Tool path field provided but empty
	TOOL_NOT_FOUND = 2,      ## Executable file not found at resolved path
	INVALID_PROJECT_DIR = 3, ## Project directory is empty or invalid
	SPAWN_FAILED = 4,        ## OS.create_process() returned error
	OFFLINE_CONFIG_FAILED = 5, ## Offline tool configuration injection failed
	TOOL_PATH_ABSOLUTE = 6,     ## Tool path is absolute and disallowed
	TOOL_PATH_OUTSIDE_ROOT = 7, ## Tool path resolves outside the project root
	TOOL_HASH_INVALID = 8,      ## Tool sha256 value is invalid or unreadable
	TOOL_HASH_MISMATCH = 9      ## Tool sha256 does not match file contents
}


## Launches a tool from the manifest with the project directory as working context.
##
## @param tool_entry: Dictionary with keys: id, version, (optional) path
## @param project_dir: Absolute path to the project root (where stack.json lives)
## @return: Dictionary with keys: success (bool), error_code (int), error_message (String), pid (int, -1 if failed)
static func launch(tool_entry: Dictionary, project_dir: String) -> Dictionary:
	# Validate inputs
	if project_dir.is_empty():
		Logger.warn("tool_launch_failed", {"component": "launcher", "reason": "empty_project_dir"})
		return _error_result(LaunchError.INVALID_PROJECT_DIR, "Project directory path is empty.")
	
	var tool_id = String(tool_entry.get("id", "unknown"))
	var tool_version = String(tool_entry.get("version", ""))
	var full_tool_path := ""
	
	# Check if path is provided (legacy support for project-relative paths)
	if tool_entry.has("path"):
		var tool_path = String(tool_entry["path"])
		if tool_path.is_empty():
			Logger.warn("tool_launch_failed", {"component": "launcher", "reason": "empty_path"})
			return _error_result(LaunchError.TOOL_PATH_MISSING, "Tool path is empty.")
		
		# Resolve tool path (relative paths only, within project root)
		if tool_path.is_absolute_path():
			Logger.warn("tool_launch_failed", {"component": "launcher", "reason": "absolute_path"})
			return _error_result(LaunchError.TOOL_PATH_ABSOLUTE, "Tool path must be project-relative.")
		full_tool_path = project_dir.path_join(tool_path)
		if not _is_path_under_root(full_tool_path, project_dir):
			Logger.warn("tool_launch_failed", {"component": "launcher", "reason": "path_escape"})
			return _error_result(LaunchError.TOOL_PATH_OUTSIDE_ROOT, "Tool path escapes project root.")
	else:
		# Path not provided - resolve from library
		var library = LibraryManager.new()
		var library_result = _resolve_tool_from_library(library, tool_id, tool_version)
		if not library_result["success"]:
			Logger.warn("tool_launch_failed", {"component": "launcher", "reason": "library_resolution_failed", "tool": tool_id})
			return _error_result(library_result["error_code"], library_result["error_message"])
		full_tool_path = library_result["executable_path"]
	
	if not FileAccess.file_exists(full_tool_path):
		Logger.warn("tool_launch_failed", {"component": "launcher", "reason": "not_found", "tool": tool_id})
		return _error_result(LaunchError.TOOL_NOT_FOUND, "Tool executable not found at: %s" % full_tool_path)

	var hash_check = _validate_tool_hash(tool_entry, full_tool_path)
	if not hash_check["success"]:
		Logger.warn("tool_launch_failed", {"component": "launcher", "reason": "hash_check", "tool": tool_id})
		return _error_result(hash_check["error_code"], hash_check["error_message"])
	
	# Build tool-specific arguments
	var args = _build_launch_arguments(tool_id, project_dir)
	if OfflineEnforcer.is_offline():
		var inject = ToolConfigInjector.apply(tool_id, project_dir)
		if not inject["success"]:
			Logger.warn("tool_launch_failed", {"component": "launcher", "reason": "offline_inject", "tool": tool_id})
			return _error_result(LaunchError.OFFLINE_CONFIG_FAILED, inject["error_message"])
		args.append_array(inject["args"])
	
	# Spawn the process
	var pid = OS.create_process(full_tool_path, args)
	if pid == -1:
		Logger.error("tool_launch_failed", {"component": "launcher", "reason": "spawn_failed", "tool": tool_id})
		return _error_result(LaunchError.SPAWN_FAILED, "Failed to spawn process for tool: %s" % tool_id)
	Logger.info("tool_launched", {"component": "launcher", "tool": tool_id, "project": project_dir.get_file()})
	
	return {
		"success": true,
		"error_code": LaunchError.SUCCESS,
		"error_message": "",
		"pid": pid
	}


## Builds tool-specific launch arguments.
##
## Different tools require different arguments to operate in the project context:
## - Godot: --path <project_dir> (opens the project)
## - Blender: (no special args needed, opens blank scene)
## - Other tools: (no special args for now)
static func _build_launch_arguments(tool_id: String, project_dir: String) -> PackedStringArray:
	var args = PackedStringArray()
	
	match tool_id:
		"godot":
			# Godot needs --path to open a project
			args.append("--path")
			args.append(project_dir)
		"blender":
			# Blender opens with default scene, no special args needed
			pass
		_:
			# Unknown tools launch without special args
			pass
	
	return args


## Helper to construct error result dictionaries.
static func _error_result(error_code: LaunchError, message: String) -> Dictionary:
	return {
		"success": false,
		"error_code": error_code,
		"error_message": message,
		"pid": -1
	}

## Ensures the resolved path stays inside the project root.
static func _is_path_under_root(full_path: String, project_root: String) -> bool:
	var normalized_root = project_root.simplify_path().to_lower()
	var normalized_path = full_path.simplify_path().to_lower()
	if normalized_path == normalized_root:
		return true
	return normalized_path.begins_with(normalized_root + "/")

## Resolves tool executable path from the library.
## Parameters:
##   library (LibraryManager): Library manager instance
##   tool_id (String): Tool identifier (e.g., "godot", "blender")
##   tool_version (String): Tool version (e.g., "4.3", "4.2")
## Returns:
##   Dictionary: {success: bool, error_code: int, error_message: String, executable_path: String}
static func _resolve_tool_from_library(library: LibraryManager, tool_id: String, tool_version: String) -> Dictionary:
	if not library.tool_exists(tool_id, tool_version):
		return {
			"success": false,
			"error_code": LaunchError.TOOL_NOT_FOUND,
			"error_message": "Tool %s v%s not found in library" % [tool_id, tool_version],
			"executable_path": ""
		}
	
	var tool_dir = library.get_tool_path(tool_id, tool_version)
	if tool_dir.is_empty():
		return {
			"success": false,
			"error_code": LaunchError.TOOL_NOT_FOUND,
			"error_message": "Failed to resolve library path for %s v%s" % [tool_id, tool_version],
			"executable_path": ""
		}
	
	# Find executable within tool directory
	var executable_path = _find_executable_in_directory(tool_dir, tool_id)
	if executable_path.is_empty():
		return {
			"success": false,
			"error_code": LaunchError.TOOL_NOT_FOUND,
			"error_message": "No executable found in tool directory: %s" % tool_dir,
			"executable_path": ""
		}
	
	return {
		"success": true,
		"error_code": LaunchError.SUCCESS,
		"error_message": "",
		"executable_path": executable_path
	}

## Finds the main executable within a tool directory.
## Uses tool-specific conventions to locate the executable.
## Parameters:
##   directory (String): Absolute path to tool directory
##   tool_id (String): Tool identifier for convention-based search
## Returns:
##   String: Absolute path to executable, or empty string if not found
static func _find_executable_in_directory(directory: String, tool_id: String) -> String:
	var dir = DirAccess.open(directory)
	if dir == null:
		return ""
	
	# Tool-specific executable naming conventions
	match tool_id:
		"godot":
			# Look for Godot_*.exe or godot.exe
			dir.list_dir_begin()
			var godot_file = dir.get_next()
			while godot_file != "":
				if godot_file.to_lower().begins_with("godot") and godot_file.to_lower().ends_with(".exe"):
					var exe_path = directory.path_join(godot_file)
					if FileAccess.file_exists(exe_path):
						return exe_path
				godot_file = dir.get_next()
			dir.list_dir_end()
		"blender":
			# Look for blender.exe
			var blender_exe = directory.path_join("blender.exe")
			if FileAccess.file_exists(blender_exe):
				return blender_exe
		"krita":
			# Look for bin/krita.exe or krita.exe
			var krita_bin = directory.path_join("bin").path_join("krita.exe")
			if FileAccess.file_exists(krita_bin):
				return krita_bin
			var krita_exe = directory.path_join("krita.exe")
			if FileAccess.file_exists(krita_exe):
				return krita_exe
		"audacity":
			# Look for audacity.exe
			var audacity_exe = directory.path_join("audacity.exe")
			if FileAccess.file_exists(audacity_exe):
				return audacity_exe
	
	# Fallback: find first .exe file in directory
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".exe"):
			var exe_path = directory.path_join(file_name)
			if FileAccess.file_exists(exe_path):
				dir.list_dir_end()
				return exe_path
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return ""


## Validates sha256 when present in the tool entry.
static func _validate_tool_hash(tool_entry: Dictionary, full_tool_path: String) -> Dictionary:
	if not tool_entry.has("sha256"):
		return {"success": true}
	var sha_value = String(tool_entry.get("sha256", "")).strip_edges().to_lower()
	if sha_value.is_empty() or not _is_hex_sha256(sha_value):
		return {
			"success": false,
			"error_code": LaunchError.TOOL_HASH_INVALID,
			"error_message": "Tool sha256 value is invalid."
		}
	var hash_result = _compute_sha256(full_tool_path)
	if not hash_result["success"]:
		return {
			"success": false,
			"error_code": LaunchError.TOOL_HASH_INVALID,
			"error_message": hash_result["error_message"]
		}
	if hash_result["sha256"] != sha_value:
		return {
			"success": false,
			"error_code": LaunchError.TOOL_HASH_MISMATCH,
			"error_message": "Tool sha256 does not match file contents."
		}
	return {"success": true}

## Computes sha256 for a file path using streaming reads.
static func _compute_sha256(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error_message": "Failed to read tool for hashing."}
	var hasher = HashingContext.new()
	var start_err = hasher.start(HashingContext.HASH_SHA256)
	if start_err != OK:
		file.close()
		return {"success": false, "error_message": "Failed to initialize hash context."}
	while not file.eof_reached():
		var chunk = file.get_buffer(1024 * 1024)
		if chunk.size() == 0:
			break
		hasher.update(chunk)
	file.close()
	var digest = hasher.finish()
	return {"success": true, "sha256": digest.hex_encode().to_lower()}

## Validates sha256 hex format (64 hex characters).
static func _is_hex_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		var code = character.unicode_at(0)
		var is_digit = code >= 48 and code <= 57
		var is_lower = code >= 97 and code <= 102
		if not (is_digit or is_lower):
			return false
	return true
