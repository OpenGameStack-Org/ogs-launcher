## ProjectsController: Projects page coordinator for loading manifests and configs.
##
## Handles project selection, stack.json validation, ogs_config.json loading,
## offline status updates, and tool launch requests from the Projects page UI.

extends RefCounted
class_name ProjectsController

const ToolLauncher = preload("res://scripts/launcher/tool_launcher.gd")
const OfflineEnforcer = preload("res://scripts/network/offline_enforcer.gd")
const Logger = preload("res://scripts/logging/logger.gd")

## Emitted when offline state changes after loading a project or config.
signal offline_state_changed(active: bool, reason: String)

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

func setup(
	path_line_edit: LineEdit,
	browse_button: Button,
	load_button: Button,
	new_button: Button,
	status_label: Label,
	offline_label: Label,
	tools_list_control: ItemList,
	launch_button: Button,
	dir_dialog: FileDialog
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

	btn_browse_project.pressed.connect(_on_browse_project_pressed)
	btn_load_project.pressed.connect(_on_load_project_pressed)
	btn_new_project.pressed.connect(_on_new_project_pressed)
	btn_launch_tool.pressed.connect(_on_launch_tool_pressed)
	project_path_line_edit.text_submitted.connect(_on_project_path_submitted)
	project_dir_dialog.dir_selected.connect(_on_project_dir_selected)
	
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
	_enable_launch_button()

	var config = _load_config_if_present(config_path)
	_apply_offline_config(config)
	_update_offline_status(config)

func _load_config_if_present(config_path: String) -> OgsConfig:
	"""Loads ogs_config.json if present; returns a default config otherwise."""
	if not FileAccess.file_exists(config_path):
		return OgsConfig.new()
	return OgsConfig.load_from_file(config_path)

func _populate_tools_list(tools: Array) -> void:
	"""Populates the tools list UI from the manifest tool entries."""
	tools_list.clear()
	for tool_entry in tools:
		var tool_id = String(tool_entry.get("id", "unknown"))
		var tool_version = String(tool_entry.get("version", "?"))
		var tool_path = String(tool_entry.get("path", ""))
		var label = "%s v%s - %s" % [tool_id, tool_version, tool_path]
		tools_list.add_item(label)

func _update_status(message: String) -> void:
	"""Updates the projects status label."""
	lbl_project_status.text = message

func _update_offline_status(config: OgsConfig) -> void:
	"""Updates the offline status label based on config state."""
	if config == null:
		lbl_offline_status.text = "Offline: Unknown"
		return
	if config.force_offline:
		lbl_offline_status.text = "Offline: Forced (force_offline=true)"
	elif config.offline_mode:
		lbl_offline_status.text = "Offline: Enabled (offline_mode=true)"
	else:
		lbl_offline_status.text = "Offline: Disabled"

func _apply_offline_config(config: OgsConfig) -> void:
	"""Applies offline configuration and notifies listeners."""
	OfflineEnforcer.apply_config(config)
	offline_state_changed.emit(OfflineEnforcer.is_offline(), OfflineEnforcer.get_reason())

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
