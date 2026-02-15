extends RefCounted
class_name ToolLauncher

## Handles spawning external tools from the frozen stack with correct environment and working directory.
##
## This class is responsible for:
## - Resolving tool paths relative to the project directory
## - Building tool-specific launch arguments (e.g., Godot's --path flag)
## - Spawning processes in a way that respects air-gap constraints
## - Returning detailed error information for troubleshooting

## Error codes for launch failures
enum LaunchError {
	SUCCESS = 0,
	TOOL_PATH_MISSING = 1,   ## Tool entry lacks "path" field
	TOOL_NOT_FOUND = 2,      ## Executable file not found at resolved path
	INVALID_PROJECT_DIR = 3, ## Project directory is empty or invalid
	SPAWN_FAILED = 4,        ## OS.create_process() returned error
}


## Launches a tool from the manifest with the project directory as working context.
##
## @param tool_entry: Dictionary with keys: id, version, path
## @param project_dir: Absolute path to the project root (where stack.json lives)
## @return: Dictionary with keys: success (bool), error_code (int), error_message (String), pid (int, -1 if failed)
static func launch(tool_entry: Dictionary, project_dir: String) -> Dictionary:
	# Validate inputs
	if project_dir.is_empty():
		return _error_result(LaunchError.INVALID_PROJECT_DIR, "Project directory path is empty.")
	
	if not tool_entry.has("path"):
		return _error_result(LaunchError.TOOL_PATH_MISSING, "Tool entry is missing 'path' field.")
	
	var tool_path = String(tool_entry["path"])
	if tool_path.is_empty():
		return _error_result(LaunchError.TOOL_PATH_MISSING, "Tool path is empty.")
	
	# Resolve tool path (absolute paths used as-is, relative paths joined with project dir)
	var full_tool_path = tool_path
	if not tool_path.is_absolute_path():
		full_tool_path = project_dir.path_join(tool_path)
	
	if not FileAccess.file_exists(full_tool_path):
		return _error_result(LaunchError.TOOL_NOT_FOUND, "Tool executable not found at: %s" % full_tool_path)
	
	# Build tool-specific arguments
	var tool_id = String(tool_entry.get("id", "unknown"))
	var args = _build_launch_arguments(tool_id, project_dir)
	
	# Spawn the process
	var pid = OS.create_process(full_tool_path, args)
	if pid == -1:
		return _error_result(LaunchError.SPAWN_FAILED, "Failed to spawn process for tool: %s" % tool_id)
	
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
