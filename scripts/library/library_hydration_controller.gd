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
##   controller.setup(dialog_node, tools_list, status_label, download_button, "", null, "", "")
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
var scene_tree: SceneTree
var active_hydration := false
var current_missing_tools: Array = []
var using_mirror := false
var using_remote := false

func setup(
	hydration_dialog: Node,
	tools_list: ItemList,
	status_text: Label,
	btn_download: Button,
	mirror_url: String = "",
	tree: SceneTree = null,
	mirror_root_override: String = "",
	remote_repo_url: String = ""
) -> void:
	"""Wires the hydration UI controls to the controller.
	Parameters:
	  hydration_dialog (Node): The dialog/popup containing hydration UI
	  tools_list (ItemList): Control showing list of tools to download
	  status_text (Label): Status/progress label
	  btn_download (Button): "Download and Install" button
	  mirror_url (String): Mirror URL for downloads
	  tree (SceneTree): Scene tree reference for timers (auto-detected if null)
	  mirror_root_override (String): Optional mirror root path for offline hydration
	  remote_repo_url (String): Optional remote repository.json URL
	"""
	dialog = hydration_dialog
	tools_list_control = tools_list
	status_label = status_text
	download_button = btn_download
	scene_tree = tree if tree else hydration_dialog.get_tree()

	hydrator = LibraryHydrator.new(mirror_url)
	mirror_resolver = MirrorPathResolverScript.new()
	mirror_root = mirror_root_override if not mirror_root_override.is_empty() else mirror_resolver.get_mirror_root()
	mirror_hydrator = MirrorHydratorScript.new(mirror_root)
	remote_repository_url = remote_repo_url
	if not remote_repository_url.is_empty():
		remote_hydrator = RemoteMirrorHydratorScript.new(remote_repository_url)
	
	# Wire signals
	hydrator.tool_download_started.connect(_on_tool_download_started)
	hydrator.tool_download_complete.connect(_on_tool_download_complete)
	hydrator.hydration_complete.connect(_on_hydration_complete)
	
	mirror_hydrator.tool_install_started.connect(_on_tool_install_started)
	mirror_hydrator.tool_install_complete.connect(_on_tool_install_complete)
	mirror_hydrator.hydration_complete.connect(_on_hydration_complete)
	if remote_hydrator != null:
		remote_hydrator.tool_install_started.connect(_on_tool_install_started)
		remote_hydrator.tool_install_complete.connect(_on_tool_install_complete)
		remote_hydrator.hydration_complete.connect(_on_hydration_complete)
	
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

## Updates the mirror root path dynamically.
func update_mirror_root(new_mirror_root: String) -> void:
	"""Updates the mirror root path and recreates the mirror hydrator.
	Parameters:
	  new_mirror_root (String): New mirror root path, or empty string for default
	"""
	mirror_root = new_mirror_root if not new_mirror_root.is_empty() else mirror_resolver.get_mirror_root()
	mirror_hydrator = MirrorHydratorScript.new(mirror_root)
	# Re-wire signals
	mirror_hydrator.tool_install_started.connect(_on_tool_install_started)
	mirror_hydrator.tool_install_complete.connect(_on_tool_install_complete)
	mirror_hydrator.hydration_complete.connect(_on_hydration_complete)
	Logger.info("mirror_root_updated", {"component": "library", "path": mirror_root})

## Updates the remote repository URL dynamically.
func update_remote_repository_url(new_repo_url: String) -> void:
	"""Updates the remote repository URL and recreates the remote hydrator."""
	remote_repository_url = new_repo_url
	remote_hydrator = null
	if not remote_repository_url.is_empty():
		remote_hydrator = RemoteMirrorHydratorScript.new(remote_repository_url)
		remote_hydrator.tool_install_started.connect(_on_tool_install_started)
		remote_hydrator.tool_install_complete.connect(_on_tool_install_complete)
		remote_hydrator.hydration_complete.connect(_on_hydration_complete)
	Logger.info("remote_repo_updated", {"component": "library"})

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
	_update_status("Starting mirror install...")
	
	Logger.info("hydration_started", {
		"component": "library",
		"tool_count": current_missing_tools.size()
	})

	# Non-blocking: start hydration
	if using_remote and remote_hydrator != null:
		_update_status("Starting remote mirror download...")
		remote_hydrator.hydrate(current_missing_tools)
		return
	mirror_hydrator.hydrate(current_missing_tools)
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

func _on_tool_install_started(tool_id: String, version: String) -> void:
	"""Called when a mirror install starts."""
	if using_remote:
		_update_status("Downloading %s v%s from remote mirror..." % [tool_id, version])
	else:
		_update_status("Installing %s v%s from local mirror..." % [tool_id, version])
	Logger.debug("mirror_install_started", {
		"component": "mirror",
		"tool_id": tool_id,
		"version": version
	})

func _on_tool_install_complete(tool_id: String, version: String, success: bool, error_message: String) -> void:
	"""Called when a mirror install completes."""
	if success:
		_update_status("✓ %s v%s installed successfully." % [tool_id, version])
	else:
		_update_status("✗ Failed to install %s v%s: %s" % [tool_id, version, error_message])

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
