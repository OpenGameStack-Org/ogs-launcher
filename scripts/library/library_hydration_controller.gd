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
##   controller.setup(dialog_node, tools_list, status_label, progress_bar, download_button, "", null, "", "")
##   controller.start_hydration(missing_tools)

extends RefCounted
class_name LibraryHydrationController

const MirrorHydratorScript = preload("res://scripts/mirror/mirror_hydrator.gd")
const MirrorPathResolverScript = preload("res://scripts/mirror/mirror_path_resolver.gd")
const RemoteMirrorHydratorScript = preload("res://scripts/mirror/remote_mirror_hydrator.gd")

## Emitted when hydration completes (success or failure).
signal hydration_finished(success: bool, message: String)

var hydrator: LibraryHydrator
var mirror_hydrator
var mirror_resolver
var mirror_root: String = ""
var remote_repository_url: String = ""
var remote_hydrator
var dialog: Node
var tools_list_control: ItemList
var status_label: Label
var download_button: Button
var close_button: Button
var progress_dialog: Node
var progress_status_label: Label
var progress_progress_bar: ProgressBar
var progress_cancel_button: Button
var progress_ok_button: Button
var scene_tree: SceneTree
var active_hydration := false
var hydration_cancelled := false
var current_missing_tools: Array = []
var selected_tools: Array = []
var tools_index_map: Array = []
var active_tool_total := 0
var active_tool_completed := 0
var active_tool_bytes_downloaded := 0
var active_tool_total_bytes := 0
var using_mirror := false
var using_remote := false

func setup(
	hydration_dialog: Node,
	tools_list: ItemList,
	status_text: Label,
	btn_download: Button,
	btn_close: Button = null,
	prog_dialog: Node = null,
	prog_status: Label = null,
	prog_bar: ProgressBar = null,
	prog_cancel: Button = null,
	prog_ok: Button = null,
	mirror_url: String = "",
	tree: SceneTree = null,
	mirror_root_override: String = "",
	remote_repo_url: String = ""
) -> void:
	"""Wires the hydration UI controls to the controller.
	Parameters:
	  hydration_dialog (Node): The dialog/popup containing hydration UI
	  tools_list (ItemList): Control showing list of tools to download
	  status_text (Label): Status label in hydration dialog
	  btn_download (Button): "Download and Install" button
	  btn_close (Button): Optional "Close" button to dismiss the dialog
	  prog_dialog (Node): Optional progress dialog modal
	  prog_status (Label): Optional progress status label
	  prog_bar (ProgressBar): Optional progress bar for download tracking
	  prog_cancel (Button): Optional cancel button
	  prog_ok (Button): Optional OK button for completion
	  mirror_url (String): Mirror URL for downloads
	  tree (SceneTree): Scene tree reference for timers (auto-detected if null)
	  mirror_root_override (String): Optional mirror root path for offline hydration
	  remote_repo_url (String): Optional remote repository.json URL
	"""
	dialog = hydration_dialog
	tools_list_control = tools_list
	status_label = status_text
	download_button = btn_download
	close_button = btn_close
	progress_dialog = prog_dialog
	progress_status_label = prog_status
	progress_progress_bar = prog_bar
	progress_cancel_button = prog_cancel
	progress_ok_button = prog_ok
	scene_tree = tree if tree else hydration_dialog.get_tree()

	hydrator = LibraryHydrator.new(mirror_url)
	mirror_resolver = MirrorPathResolverScript.new()
	mirror_root = mirror_root_override if not mirror_root_override.is_empty() else mirror_resolver.get_mirror_root()
	mirror_hydrator = MirrorHydratorScript.new(mirror_root, scene_tree)
	remote_repository_url = remote_repo_url
	if not remote_repository_url.is_empty():
		remote_hydrator = RemoteMirrorHydratorScript.new(remote_repository_url, scene_tree)
	
	# Wire signals
	hydrator.tool_download_started.connect(_on_tool_download_started)
	hydrator.tool_download_complete.connect(_on_tool_download_complete)
	hydrator.hydration_complete.connect(_on_hydration_complete)
	
	mirror_hydrator.tool_install_started.connect(_on_tool_install_started)
	mirror_hydrator.tool_install_complete.connect(_on_tool_install_complete)
	mirror_hydrator.tool_download_progress.connect(_on_tool_download_progress)
	mirror_hydrator.hydration_complete.connect(_on_hydration_complete)
	if remote_hydrator != null:
		remote_hydrator.tool_install_started.connect(_on_tool_install_started)
		remote_hydrator.tool_install_complete.connect(_on_tool_install_complete)
		remote_hydrator.tool_download_progress.connect(_on_tool_download_progress)
		remote_hydrator.hydration_complete.connect(_on_hydration_complete)
	
	download_button.pressed.connect(_on_download_button_pressed)
	
	# Wire close button if provided
	if close_button != null:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# Wire progress dialog buttons if provided
	if progress_cancel_button != null:
		progress_cancel_button.pressed.connect(_on_progress_cancel_pressed)
	if progress_ok_button != null:
		progress_ok_button.pressed.connect(_on_progress_ok_pressed)
	
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
	
	# Show dialog (only if in tree, e.g., not in unit tests)
	if dialog and not dialog.visible and dialog.is_inside_tree():
		dialog.show()
	
	# Populate tools list
	_populate_tools_list(missing_tools)

	using_mirror = _is_local_mirror_available()
	using_remote = false
	if not using_mirror:
		using_remote = _is_remote_mirror_available()
		if not using_remote:
			_update_status("Error: No mirror repository configured. Cannot install tools.")
			_disable_download_button()
			Logger.warn("hydration_blocked", {
				"component": "library",
				"reason": "mirror repository missing"
			})
			return
	
	# Show count of tools
	var already_count = hydrator.count_already_installed(missing_tools)
	var to_download = missing_tools.size() - already_count
	
	if to_download > 0:
		if using_remote:
			_update_status("Ready to download %d tool(s) from remote mirror." % to_download)
		else:
			_update_status("Ready to install %d tool(s) from local mirror." % to_download)
		_enable_download_button()
	else:
		_update_status("All tools already in library!")
		_disable_download_button()

## Closes the hydration dialog.
func close_dialog() -> void:
	"""Closes the hydration dialog."""
	if dialog and dialog.visible:
		dialog.hide()
	_reset_progress()

## Called when close button is pressed.
func _on_close_button_pressed() -> void:
	"""Closes the dialog when user clicks Close button."""
	close_dialog()

## Updates the mirror root path dynamically.
func update_mirror_root(new_mirror_root: String) -> void:
	"""Updates the mirror root path and recreates the mirror hydrator.
	Parameters:
	  new_mirror_root (String): New mirror root path, or empty string for default
	"""
	mirror_root = new_mirror_root if not new_mirror_root.is_empty() else mirror_resolver.get_mirror_root()
	mirror_hydrator = MirrorHydratorScript.new(mirror_root, scene_tree)
	# Re-wire signals
	mirror_hydrator.tool_install_started.connect(_on_tool_install_started)
	mirror_hydrator.tool_install_complete.connect(_on_tool_install_complete)
	mirror_hydrator.tool_download_progress.connect(_on_tool_download_progress)
	mirror_hydrator.hydration_complete.connect(_on_hydration_complete)
	Logger.info("mirror_root_updated", {"component": "library", "path": mirror_root})

## Updates the remote repository URL dynamically.
func update_remote_repository_url(new_repo_url: String) -> void:
	"""Updates the remote repository URL and recreates the remote hydrator."""
	remote_repository_url = new_repo_url
	remote_hydrator = null
	if not remote_repository_url.is_empty():
		remote_hydrator = RemoteMirrorHydratorScript.new(remote_repository_url, scene_tree)
		remote_hydrator.tool_install_started.connect(_on_tool_install_started)
		remote_hydrator.tool_install_complete.connect(_on_tool_install_complete)
		remote_hydrator.tool_download_progress.connect(_on_tool_download_progress)
		remote_hydrator.hydration_complete.connect(_on_hydration_complete)
	Logger.info("remote_repo_updated", {"component": "library"})

# Private: Populates the tools list UI with missing tools.
func _populate_tools_list(tools: Array) -> void:
	"""Shows the missing tools in the list control."""
	tools_list_control.clear()
	tools_index_map.clear()
	
	for tool_entry in tools:
		var tool_id = tool_entry.get("tool_id", "unknown")
		var version = tool_entry.get("version", "?")
		var label = "%s v%s" % [tool_id, version]
		
		if hydrator.library.tool_exists(tool_id, version):
			label += " (already installed)"
		
		tools_list_control.add_item(label)
		tools_index_map.append(tool_entry)

# Private: Updates the status label.
func _update_status(message: String) -> void:
	"""Updates the status display."""
	if status_label:
		status_label.text = message

func _update_progress() -> void:
	"""Updates the progress bar with smooth progress calculation.
	Combines completed tools with fractional progress of the current tool being downloaded.
	"""
	if progress_progress_bar and active_tool_total > 0:
		# Calculate fraction of current tool downloaded
		var current_tool_fraction = 0.0
		if active_tool_total_bytes > 0:
			current_tool_fraction = float(active_tool_bytes_downloaded) / float(active_tool_total_bytes)
		
		# Smooth progress = (completed + current_fraction) / total
		var smooth_progress = (float(active_tool_completed) + current_tool_fraction) / float(active_tool_total)
		smooth_progress = clamp(smooth_progress, 0.0, 1.0)
		
		# Set bar value to smooth progress * max_value
		progress_progress_bar.value = smooth_progress * progress_progress_bar.max_value

func _reset_progress() -> void:
	"""Resets the progress bar to its idle state."""
	if progress_progress_bar:
		progress_progress_bar.visible = false
		progress_progress_bar.value = 0
		progress_progress_bar.min_value = 0
		progress_progress_bar.max_value = 1

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
		if progress_status_label:
			progress_status_label.text = "Download already in progress..."
		return
	
	if current_missing_tools.is_empty():
		_update_status("No tools to download.")
		return

	var tools_to_process: Array = []
	if tools_list_control:
		var selected_indices = tools_list_control.get_selected_items()
		if not selected_indices.is_empty():
			for index in selected_indices:
				if index >= 0 and index < tools_index_map.size():
					tools_to_process.append(tools_index_map[index])
			if tools_to_process.is_empty():
				_update_status("No valid tools selected.")
				return
		else:
			tools_to_process = current_missing_tools
	else:
		tools_to_process = current_missing_tools
	
	# Save selected tools for potential rollback
	self.selected_tools = tools_to_process.duplicate()
	
	# Close hydration dialog and show progress dialog
	if dialog and dialog.visible:
		dialog.hide()
	
	# Prepare progress dialog
	if progress_dialog:
		hydration_cancelled = false
		active_hydration = true
		active_tool_total = tools_to_process.size()
		active_tool_completed = 0
		
		# Reset and show progress UI
		if progress_progress_bar:
			progress_progress_bar.min_value = 0
			progress_progress_bar.max_value = max(1, active_tool_total)
			progress_progress_bar.value = 0
		
		if progress_status_label:
			progress_status_label.text = "Starting downloads..."
		
		# Show Cancel button, hide OK button
		if progress_cancel_button:
			progress_cancel_button.visible = true
		if progress_ok_button:
			progress_ok_button.visible = false
		
		progress_dialog.show()
	else:
		# Fallback if no progress dialog
		active_hydration = true
		active_tool_total = tools_to_process.size()
		active_tool_completed = 0
		_disable_download_button()
		_update_status("Starting mirror install...")
	
	Logger.info("hydration_started", {
		"component": "library",
		"tool_count": tools_to_process.size()
	})

	# Non-blocking: start hydration
	if using_remote and remote_hydrator != null:
		if progress_status_label:
			progress_status_label.text = "Starting remote mirror download..."
		remote_hydrator.hydrate_async(tools_to_process)
		return
	
	if progress_status_label:
		progress_status_label.text = "Installing from local mirror..."
	mirror_hydrator.hydrate_async(tools_to_process)
	# Note: Signals will update UI as progress happens

## Called when progress dialog Cancel button is clicked.
func _on_progress_cancel_pressed() -> void:
	"""Cancels the active hydration and closes the progress dialog."""
	hydration_cancelled = true
	active_hydration = false
	
	if progress_dialog and progress_dialog.visible:
		progress_dialog.hide()
	
	# Re-open hydration dialog
	if dialog and dialog.is_inside_tree():
		dialog.show()
	
	Logger.info("hydration_cancelled", {
		"component": "library"
	})

## Called when progress dialog OK button is clicked.
func _on_progress_ok_pressed() -> void:
	"""Closes the progress dialog after completion."""
	if progress_dialog and progress_dialog.visible:
		progress_dialog.hide()
	
	# Signal completion to ProjectsController
	hydration_finished.emit(true, "Library hydration successful! All tools are ready.")

# Private: Tool download started signal handler.
func _on_tool_download_started(tool_id: String, version: String) -> void:
	"""Called when a tool download starts."""
	if hydration_cancelled:
		return
	
	var msg = "Downloading %s v%s..." % [tool_id, version]
	if progress_status_label:
		progress_status_label.text = msg
	
	Logger.debug("tool_download_started", {
		"component": "library",
		"tool_id": tool_id,
		"version": version
	})

# Private: Tool download complete signal handler.
func _on_tool_download_complete(tool_id: String, version: String, success: bool, error_message: String) -> void:
	"""Called when a tool download completes."""
	if hydration_cancelled:
		return
	
	var msg: String
	if success:
		msg = "✓ %s v%s downloaded successfully." % [tool_id, version]
	else:
		msg = "✗ Failed to download %s v%s: %s" % [tool_id, version, error_message]
	
	if progress_status_label:
		progress_status_label.text = msg
	
	active_tool_completed += 1
	_update_progress()

func _on_tool_install_started(tool_id: String, version: String) -> void:
	"""Called when a mirror install starts."""
	if hydration_cancelled:
		return
	
	# Reset download progress for the new tool
	active_tool_bytes_downloaded = 0
	active_tool_total_bytes = 0
	
	var msg: String
	if using_remote:
		msg = "Downloading %s v%s from remote mirror..." % [tool_id, version]
	else:
		msg = "Installing %s v%s from local mirror..." % [tool_id, version]
	
	if progress_status_label:
		progress_status_label.text = msg
	
	Logger.debug("mirror_install_started", {
		"component": "mirror",
		"tool_id": tool_id,
		"version": version
	})

func _on_tool_install_complete(tool_id: String, version: String, success: bool, error_message: String) -> void:
	"""Called when a mirror install completes."""
	if hydration_cancelled:
		return
	
	var msg: String
	if success:
		msg = "✓ %s v%s installed successfully." % [tool_id, version]
	else:
		msg = "✗ Failed to install %s v%s: %s" % [tool_id, version, error_message]
	
	if progress_status_label:
		progress_status_label.text = msg
	
	active_tool_completed += 1
	_update_progress()

func _on_tool_download_progress(_tool_id: String, _version: String, bytes_downloaded: int, total_bytes: int) -> void:
	"""Called when download progress is reported for a tool."""
	if hydration_cancelled:
		return
	
	active_tool_bytes_downloaded = bytes_downloaded
	active_tool_total_bytes = total_bytes
	_update_progress()

# Private: Hydration complete signal handler.
func _on_hydration_complete(success: bool, failed_tools: Array) -> void:
	"""Called when all downloads complete."""
	if hydration_cancelled:
		return
	
	active_hydration = false
	_reset_progress()
	
	var completion_msg: String
	if success:
		if selected_tools.size() == 1:
			var tool_name = selected_tools[0].get("tool_id", "tool")
			completion_msg = "%s has been installed" % tool_name
		else:
			completion_msg = "All %d tools have been installed" % selected_tools.size()
		
		Logger.info("hydration_success", {
			"component": "library",
			"tool_count": selected_tools.size()
		})
	else:
		var fail_count = failed_tools.size()
		completion_msg = "Download failed: %d tool(s) could not be installed" % fail_count
		Logger.warn("hydration_partial", {
			"component": "library",
			"failed_count": fail_count
		})
	
	# Update progress dialog to show completion
	if progress_status_label:
		progress_status_label.text = completion_msg
	
	# Hide Cancel button and show OK button
	if progress_cancel_button:
		progress_cancel_button.visible = false
	if progress_ok_button:
		progress_ok_button.visible = true
	
	# Emit completion signal for ProjectsController (but don't close dialog yet - wait for OK click)
	hydration_finished.emit(success, _get_status_message(success, failed_tools))

# Private: Generates completion message.
func _get_status_message(success: bool, failed_tools: Array) -> String:
	"""Creates a human-readable completion message."""
	if success:
		return "Library hydration successful! All tools are ready."
	else:
		var fail_count = failed_tools.size()
		return "Library hydration completed with %d failure(s)." % fail_count

func _is_local_mirror_available() -> bool:
	"""Returns true when repository.json exists in the mirror root."""
	if mirror_root.is_empty():
		return false
	var repo_path = mirror_root.path_join("repository.json")
	return FileAccess.file_exists(repo_path)

func _is_remote_mirror_available() -> bool:
	"""Returns true when remote repository is configured and online is allowed."""
	if remote_repository_url.is_empty():
		return false
	if OfflineEnforcer.is_offline():
		return false
	return true
