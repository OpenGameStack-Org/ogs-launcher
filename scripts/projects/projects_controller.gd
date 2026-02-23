## ProjectsController: Projects page coordinator for loading manifests and configs.
##
## Handles project selection, stack.json validation, ogs_config.json loading,
## offline status updates, tool availability checking, and tool launch requests.
##
## When a project is loaded:
##   1. Loads and validates stack.json
##   2. Checks if all required tools exist in the library
##   3. Signals if tools are missing (for Tools-page guidance)
##   4. Enables launch only if environment is ready
##
## Environment Validation Flow:
##   - environment_incomplete(missing_tools) → UI disables sealing and directs to Tools page
##   - User clicks missing tool in list → tool_view_requested(tool_id, version)
##   - UI navigates to Tools page for download/install

extends RefCounted
class_name ProjectsController

## Emitted when offline state changes after loading a project or config.
signal offline_state_changed(active: bool, reason: String)

## Emitted when tools are missing from the library.
## UI can guide users to the Tools page for downloads.
signal environment_incomplete(missing_tools: Array)

## Emitted when environment is complete and ready for launch.
signal environment_ready

## Emitted when user clicks a tool to view it in Tools page.
signal tool_view_requested(tool_id: String, tool_version: String)

var project_path_line_edit: LineEdit
var btn_browse_project: Button
var btn_load_project: Button
var btn_new_project: Button
var lbl_project_status: Label
var lbl_offline_status: Label
var tools_list: ItemList
var btn_launch_tool: Button
var project_dir_dialog: FileDialog

var current_project_dir := ""
var current_manifest: StackManifest = null
var environment_validator: ProjectEnvironmentValidator
var tools_controller: ToolsController
var _tool_availability: Dictionary = {}  # Maps {tool_id: {version: {available: bool}}}
var _library_manager: LibraryManager = null

func setup(
	path_line_edit: LineEdit,
	browse_button: Button,
	load_button: Button,
	new_button: Button,
	status_label: Label,
	offline_label: Label,
	tools_list_control: ItemList,
	launch_button: Button,
	dir_dialog: FileDialog,
	tools_ctrl: ToolsController = null
) -> void:
	"""Wires the Projects page controls to project loading behaviors."""
	project_path_line_edit = path_line_edit
	btn_browse_project = browse_button
	btn_load_project = load_button
	btn_new_project = new_button
	lbl_project_status = status_label
	lbl_offline_status = offline_label
	tools_list = tools_list_control
	btn_launch_tool = launch_button
	project_dir_dialog = dir_dialog
	tools_controller = tools_ctrl

	btn_browse_project.pressed.connect(_on_browse_project_pressed)
	btn_load_project.pressed.connect(_on_load_project_pressed)
	btn_new_project.pressed.connect(_on_new_project_pressed)
	btn_launch_tool.pressed.connect(_on_launch_tool_pressed)
	project_path_line_edit.text_submitted.connect(_on_project_path_submitted)
	project_dir_dialog.dir_selected.connect(_on_project_dir_selected)
	tools_list.item_clicked.connect(func(index: int, _at_position: Vector2, _mouse_button_index: int):
		_on_tool_item_clicked(index)
	)
	
	environment_validator = ProjectEnvironmentValidator.new()
	_library_manager = LibraryManager.new()
	
	_apply_offline_config(null)

	# Initially disable launch button until a project is loaded
	btn_launch_tool.disabled = true

func _on_browse_project_pressed() -> void:
	"""Opens the folder picker for selecting a project root."""
	project_dir_dialog.popup_centered_ratio(0.65)

func _on_new_project_pressed() -> void:
	"""Provides a placeholder response until the new project wizard is implemented."""
	_update_status("Status: New Project wizard coming soon.")

func _on_project_dir_selected(dir_path: String) -> void:
	"""Updates the project path field after a directory is selected."""
	project_path_line_edit.text = dir_path
	current_project_dir = dir_path
	_update_status("Status: Project folder selected. Click Load to inspect.")

func _on_project_path_submitted(path_text: String) -> void:
	"""Loads the project when the user submits a path in the text field."""
	current_project_dir = path_text.strip_edges()
	_load_project_from_path(current_project_dir)

func _on_load_project_pressed() -> void:
	"""Loads the project using the current path input."""
	current_project_dir = project_path_line_edit.text.strip_edges()
	_load_project_from_path(current_project_dir)

func _load_project_from_path(project_dir: String) -> void:
	"""Loads and validates stack.json and ogs_config.json from a project folder."""
	if project_dir.is_empty():
		_update_status("Status: Please select a project folder.")
		Logger.warn("project_load_failed", {"component": "projects", "reason": "empty_path"})
		_apply_offline_config(null)
		_disable_launch_button()
		return

	var stack_path = project_dir.path_join("stack.json")
	var config_path = project_dir.path_join("ogs_config.json")

	if not FileAccess.file_exists(stack_path):
		_update_status("Status: stack.json not found in the selected folder.")
		_update_offline_status(null)
		Logger.warn("project_load_failed", {"component": "projects", "reason": "missing_stack"})
		_apply_offline_config(null)
		tools_list.clear()
		_disable_launch_button()
		return

	var manifest = StackManifest.load_from_file(stack_path)
	if not manifest.is_valid():
		_update_status("Status: stack.json is invalid. Errors: %s" % ", ".join(manifest.errors))
		_update_offline_status(null)
		Logger.warn("project_load_failed", {"component": "projects", "reason": "invalid_manifest"})
		_apply_offline_config(null)
		tools_list.clear()
		_disable_launch_button()
		return

	_update_status("Status: Manifest loaded for '%s'." % manifest.stack_name)
	_populate_tools_list(manifest.tools)
	Logger.info("project_loaded", {"component": "projects", "stack_name": manifest.stack_name})
	
	# Store the manifest for launching tools
	current_manifest = manifest
	
	var config = _load_config_if_present(config_path)
	_apply_offline_config(config)
	_update_offline_status(config)

	# Validate environment (library for linked projects, project tools for forced offline)
	var use_project_tools = config != null and config.force_offline
	_validate_and_report_environment(project_dir, use_project_tools)

func _load_config_if_present(config_path: String) -> OgsConfig:
	"""Loads ogs_config.json if present; returns a default config otherwise."""
	if not FileAccess.file_exists(config_path):
		return OgsConfig.new()
	return OgsConfig.load_from_file(config_path)

func _populate_tools_list(tools: Array) -> void:
	"""Populates the tools list UI from the manifest tool entries.
	
	Adds visual indicators to show tool availability status:
	- ⚠️ Yellow indicator: tool not installed but available in remote repository
	- ❌ Red indicator: tool not installed and not available anywhere
	- No indicator: tool is already installed in the library
	
	Updates the _tool_availability dictionary with status for each tool,
	enabling click-through navigation to download missing tools.
	
	Parameters:
	  tools (Array): Array of tool entries from stack.json
	"""
	tools_list.clear()
	_tool_availability.clear()
	
	# Build availability map from ToolsController
	var available_tools = _get_available_tools()
	var repository_known = tools_controller != null and tools_controller.has_repository_data()
	
	var missing_count = 0
	var available_count = 0
	var unknown_count = 0
	var installed_count = 0
	
	for tool_entry in tools:
		var tool_id = String(tool_entry.get("id", "unknown"))
		var tool_version = String(tool_entry.get("version", "?"))
		var tool_path = String(tool_entry.get("path", ""))
		
		# Check if tool is installed in library
		var is_installed = _library_manager.tool_exists(tool_id, tool_version)
		
		# Build label with indicator
		var label = "%s v%s" % [tool_id, tool_version]
		var indicator = ""
		var availability = {"available": false, "installed": is_installed}
		
		if not is_installed:
			missing_count += 1
			# Check if available in repository (only when repository data is loaded)
			if repository_known and available_tools.has(tool_id) and available_tools[tool_id].has(tool_version):
				indicator = " ⚠️"
				availability["available"] = true
				available_count += 1
			elif repository_known:
				indicator = " ❌"
				availability["available"] = false
			else:
				# Repository availability unknown yet; do not show false unavailability.
				indicator = " ⚠️"
				availability["available"] = true
				unknown_count += 1
		else:
			installed_count += 1
		
		_tool_availability["%s_%s" % [tool_id, tool_version]] = availability
		
		# Add tool path info if present
		if not tool_path.is_empty():
			label = "%s - %s%s" % [label, tool_path, indicator]
		else:
			label = label + indicator
		
		tools_list.add_item(label)
	
	Logger.info("project_tools_list_populated", {
		"component": "projects",
		"total_tools": tools.size(),
		"installed": installed_count,
		"missing_available": available_count,
		"missing_unavailable": missing_count - available_count - unknown_count,
		"missing_unknown": unknown_count,
		"repository_known": repository_known
	})

func _get_available_tools() -> Dictionary:
	"""Returns a dictionary of available (not yet installed) tools from the remote repository.
	
	Builds a map of tools that exist in the remote ToolsController but are not
	yet installed in the local library. This is used to determine which tools
	can be downloaded vs which are completely unavailable.
	
	Returns:
	  Dictionary: {tool_id: {version: {tool_data}}, ...}
	              Empty dict if ToolsController is not available
	"""
	if tools_controller == null:
		Logger.debug("get_available_tools_no_controller", {
			"component": "projects",
			"reason": "ToolsController not initialized"
		})
		return {}
	
	var categorized = tools_controller.get_categorized_tools()
	var available = {}
	var available_count = 0
	
	for category in categorized.keys():
		for tool in categorized[category]:
			if not tool.get("installed", false):
				var tool_id = String(tool.get("id", ""))
				var version = String(tool.get("version", ""))
				if not tool_id.is_empty() and not version.is_empty():
					if not available.has(tool_id):
						available[tool_id] = {}
					available[tool_id][version] = tool
					available_count += 1
	
	Logger.debug("available_tools_scanned", {
		"component": "projects",
		"available_count": available_count,
		"unique_tools": available.size()
	})
	
	return available

func _on_tool_item_clicked(index: int) -> void:
	"""Handles click on a tool in the list to enable quick navigation.
	
	When user clicks a tool that is not yet installed:
	  1. Logs the view request with tool context
	  2. Emits tool_view_requested signal to main.gd
	  3. UI navigates to Tools page for download
	
	If tool is already installed, no action is taken
	(the launch button handles launching installed tools).
	
	Parameters:
	  index (int): Index in the tools list ItemList
	"""
	if current_manifest == null or index < 0 or index >= current_manifest.tools.size():
		Logger.debug("tool_item_clicked_invalid_index", {
			"component": "projects",
			"index": index,
			"manifest_valid": current_manifest != null,
			"tools_count": current_manifest.tools.size() if current_manifest != null else 0
		})
		return
	
	var tool_entry = current_manifest.tools[index]
	var tool_id = String(tool_entry.get("id", "unknown"))
	var tool_version = String(tool_entry.get("version", "?"))
	var availability_key = "%s_%s" % [tool_id, tool_version]
	
	# Check if tool is not installed
	if availability_key in _tool_availability:
		var availability = _tool_availability[availability_key]
		if not availability["installed"]:
			Logger.info("tool_view_requested_from_projects", {
				"component": "projects",
				"tool_id": tool_id,
				"version": tool_version,
				"available_in_repo": availability["available"]
			})
			tool_view_requested.emit(tool_id, tool_version)
	

func _update_status(message: String) -> void:
	"""Updates the projects status label."""
	lbl_project_status.text = message

func _update_offline_status(config: OgsConfig) -> void:
	"""Updates the offline status label based on config state."""
	if config == null:
		lbl_offline_status.text = "Offline Mode: Unknown"
		return
	if config.force_offline:
		lbl_offline_status.text = "Offline Mode: Forced (force_offline=true)"
	elif config.offline_mode:
		lbl_offline_status.text = "Offline Mode: Enabled (offline_mode=true)"
	else:
		lbl_offline_status.text = "Offline Mode: Disabled"

func _apply_offline_config(config: OgsConfig) -> void:
	"""Applies offline configuration and notifies listeners."""
	OfflineEnforcer.apply_config(config)
	offline_state_changed.emit(OfflineEnforcer.is_offline(), OfflineEnforcer.get_reason())

## Re-evaluates tools availability and environment for the currently loaded project.
func refresh_project_tools_state() -> void:
	"""Refreshes Projects page tool indicators and readiness state.

	Use this after Tools page repository updates or completed downloads so
	the Projects list indicators, status label, and seal readiness reflect
	the current library and repository state without requiring manual reload.
	"""
	if current_project_dir.is_empty() or current_manifest == null:
		return

	var config_path = current_project_dir.path_join("ogs_config.json")
	var config = _load_config_if_present(config_path)

	_populate_tools_list(current_manifest.tools)
	_apply_offline_config(config)
	_update_offline_status(config)

	var use_project_tools = config != null and config.force_offline
	_validate_and_report_environment(current_project_dir, use_project_tools)

	Logger.info("project_tools_state_refreshed", {
		"component": "projects",
		"project": current_project_dir,
		"tool_count": current_manifest.tools.size()
	})

func _on_launch_tool_pressed() -> void:
	"""Launches the currently selected tool from the tools list."""
	if current_manifest == null:
		_update_status("Status: No project loaded. Cannot launch tool.")
		return
	
	var selected_indices = tools_list.get_selected_items()
	if selected_indices.is_empty():
		_update_status("Status: No tool selected. Select a tool from the list first.")
		return
	
	var selected_index = selected_indices[0]
	if selected_index >= current_manifest.tools.size():
		_update_status("Status: Invalid tool selection.")
		return
	
	var tool_entry = current_manifest.tools[selected_index]
	var result = ToolLauncher.launch(tool_entry, current_project_dir)
	
	if result["success"]:
		var tool_id = String(tool_entry.get("id", "unknown"))
		_update_status("Status: Launched %s (PID: %d)" % [tool_id, result["pid"]])
	else:
		_update_status("Status: Launch failed - %s" % result["error_message"])

func _enable_launch_button() -> void:
	"""Enables the launch button when a valid project is loaded."""
	if btn_launch_tool:
		btn_launch_tool.disabled = false

func _disable_launch_button() -> void:
	"""Disables the launch button when no valid project is loaded."""
	if btn_launch_tool:
		btn_launch_tool.disabled = true
	current_manifest = null
## Validates the project environment and signals if tools are missing.
func _validate_and_report_environment(project_dir: String, use_project_tools: bool = false) -> void:
	"""Checks if all required tools are available in the library.
	
	Note: Validation is non-blocking. Launch is allowed even with missing tools,
	but a signal is emitted so UI can direct users to the Tools page.
	"""
	var validation = environment_validator.validate_project(project_dir, use_project_tools)
	
	if not validation["valid"]:
		# Validation error - append to existing status
		var error_msg = ", ".join(validation["errors"])
		_update_status("Status: Manifest loaded (Environment error: %s)" % error_msg)
		Logger.warn("environment_validation_error", {
			"component": "projects",
			"project": project_dir,
			"errors": validation["errors"]
		})
		_enable_launch_button()
		return
	
	# Validation successful - check if tools are ready
	if validation["ready"]:
		# Environment complete - all tools available
		_update_status("Status: Manifest loaded. Environment ready - all tools in library.")
		_enable_launch_button()
		environment_ready.emit()
		Logger.info("environment_ready", {
			"component": "projects",
			"project": project_dir
		})
	else:
		# Tools are missing - but still allow launch with warning
		var tool_count = validation["missing_tools"].size()
		if OfflineEnforcer.is_offline():
			_update_status("Status: Manifest loaded (%d tool(s) missing - offline mode prevents downloads)." % tool_count)
		else:
			_update_status("Status: Manifest loaded (%d tool(s) missing - use Tools page to download)." % tool_count)
		_enable_launch_button()
		environment_incomplete.emit(validation["missing_tools"])
		Logger.warn("environment_incomplete", {
			"component": "projects",
			"project": project_dir,
			"missing_count": tool_count
		})