## LibraryHydrationController: Manages the Library Hydration UI (Repair Environment dialog).
##
## Coordinates the user-facing repair/hydration workflow:
##   1. Shows dialog with list of missing tools
##   2. Provides "Download and Install" button
##   3. Shows progress as downloads happen
##   4. Reports completion/errors
##   5. Closes and signals completion to ProjectsController
##
## Usage:
##   var controller = LibraryHydrationController.new()
##   controller.setup(dialog_node, tools_list, status_label, download_button)
##   controller.start_hydration(missing_tools)

extends RefCounted
class_name LibraryHydrationController

const LibraryHydrator = preload("res://scripts/library/library_hydrator.gd")
const Logger = preload("res://scripts/logging/logger.gd")

## Emitted when hydration completes (success or failure).
signal hydration_finished(success: bool, message: String)

var hydrator: LibraryHydrator
var dialog: Node
var tools_list_control: ItemList
var status_label: Label
var download_button: Button
var scene_tree: SceneTree
var active_hydration := false
var current_missing_tools: Array = []

func setup(
	hydration_dialog: Node,
	tools_list: ItemList,
	status_text: Label,
	btn_download: Button,
	mirror_url: String = "",
	tree: SceneTree = null
) -> void:
	"""Wires the hydration UI controls to the controller.
	Parameters:
	  hydration_dialog (Node): The dialog/popup containing hydration UI
	  tools_list (ItemList): Control showing list of tools to download
	  status_text (Label): Status/progress label
	  btn_download (Button): "Download and Install" button
	  mirror_url (String): Mirror URL for downloads
	  tree (SceneTree): Scene tree reference for timers (auto-detected if null)
	"""
	dialog = hydration_dialog
	tools_list_control = tools_list
	status_label = status_text
	download_button = btn_download
	scene_tree = tree if tree else hydration_dialog.get_tree()
	
	hydrator = LibraryHydrator.new(mirror_url)
	
	# Wire signals
	hydrator.tool_download_started.connect(_on_tool_download_started)
	hydrator.tool_download_complete.connect(_on_tool_download_complete)
	hydrator.hydration_complete.connect(_on_hydration_complete)
	
	download_button.pressed.connect(_on_download_button_pressed)
	
	_update_status("Ready to download tools.")
	_disable_download_button()

## Starts the hydration workflow with a list of missing tools.
## Parameters:
##   missing_tools (Array): Array of {"tool_id": String, "version": String}
func start_hydration(missing_tools: Array) -> void:
	"""Initializes the hydration dialog and shows the list of tools to download."""
	if missing_tools.is_empty():
		_update_status("No tools to download.")
		return
	
	current_missing_tools = missing_tools
	
	# Show dialog
	if dialog and not dialog.visible:
		dialog.popup_centered_ratio(0.5)
	
	# Populate tools list
	_populate_tools_list(missing_tools)
	
	# Check if mirror is configured
	if not hydrator.is_mirror_configured():
		_update_status("Error: Mirror URL not configured. Cannot download tools.")
		_disable_download_button()
		Logger.warn("hydration_blocked", {
			"component": "library",
			"reason": "mirror not configured"
		})
		return
	
	# Show count of tools
	var already_count = hydrator.count_already_installed(missing_tools)
	var to_download = missing_tools.size() - already_count
	
	if to_download > 0:
		_update_status("Ready to download %d tool(s). Click 'Download and Install'." % to_download)
		_enable_download_button()
	else:
		_update_status("All tools already in library!")
		_disable_download_button()

## Closes the hydration dialog.
func close_dialog() -> void:
	"""Closes the hydration dialog."""
	if dialog and dialog.visible:
		dialog.hide()

# Private: Populates the tools list UI with missing tools.
func _populate_tools_list(tools: Array) -> void:
	"""Shows the missing tools in the list control."""
	tools_list_control.clear()
	
	for tool_entry in tools:
		var tool_id = tool_entry.get("tool_id", "unknown")
		var version = tool_entry.get("version", "?")
		var label = "%s v%s" % [tool_id, version]
		
		if hydrator.library.tool_exists(tool_id, version):
			label += " (already installed)"
		
		tools_list_control.add_item(label)

# Private: Updates the status label.
func _update_status(message: String) -> void:
	"""Updates the status display."""
	if status_label:
		status_label.text = message

# Private: Enables the download button.
func _enable_download_button() -> void:
	"""Enables the download button."""
	if download_button:
		download_button.disabled = false

# Private: Disables the download button.
func _disable_download_button() -> void:
	"""Disables the download button."""
	if download_button:
		download_button.disabled = true

# Private: Starts the hydration process.
func _on_download_button_pressed() -> void:
	"""Triggered when user clicks the download button."""
	if active_hydration:
		_update_status("Download already in progress...")
		return
	
	if current_missing_tools.is_empty():
		_update_status("No tools to download.")
		return
	
	active_hydration = true
	_disable_download_button()
	_update_status("Starting downloads...")
	
	Logger.info("hydration_started", {
		"component": "library",
		"tool_count": current_missing_tools.size()
	})
	
	# Non-blocking: start hydration
	var result = hydrator.hydrate(current_missing_tools)
	# Note: Signals will update UI as progress happens

# Private: Tool download started signal handler.
func _on_tool_download_started(tool_id: String, version: String) -> void:
	"""Called when a tool download starts."""
	_update_status("Downloading %s v%s..." % [tool_id, version])
	Logger.debug("tool_download_started", {
		"component": "library",
		"tool_id": tool_id,
		"version": version
	})

# Private: Tool download complete signal handler.
func _on_tool_download_complete(tool_id: String, version: String, success: bool, error_message: String) -> void:
	"""Called when a tool download completes."""
	if success:
		_update_status("✓ %s v%s installed successfully." % [tool_id, version])
	else:
		_update_status("✗ Failed to download %s v%s: %s" % [tool_id, version, error_message])

# Private: Hydration complete signal handler.
func _on_hydration_complete(success: bool, failed_tools: Array) -> void:
	"""Called when all downloads complete."""
	active_hydration = false
	
	if success:
		_update_status("✓ All tools downloaded successfully!")
		Logger.info("hydration_success", {
			"component": "library",
			"tool_count": current_missing_tools.size()
		})
	else:
		var fail_count = failed_tools.size()
		_update_status("✗ Download complete with %d failure(s). See logs for details." % fail_count)
		Logger.warn("hydration_partial", {
			"component": "library",
			"failed_count": fail_count
		})
	
	# Emit completion signal for ProjectsController
	hydration_finished.emit(success, _get_status_message(success, failed_tools))
	
	# Close dialog after a brief delay
	if scene_tree:
		await scene_tree.create_timer(2.0).timeout
	close_dialog()

# Private: Generates completion message.
func _get_status_message(success: bool, failed_tools: Array) -> String:
	"""Creates a human-readable completion message."""
	if success:
		return "Library hydration successful! All tools are ready."
	else:
		var fail_count = failed_tools.size()
		return "Library hydration completed with %d failure(s)." % fail_count
