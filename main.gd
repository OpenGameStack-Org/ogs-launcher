extends Control

const MirrorPathResolverScript = preload("res://scripts/mirror/mirror_path_resolver.gd")
const DEFAULT_REMOTE_REPO_URL := "https://raw.githubusercontent.com/OpenGameStack-Org/ogs-frozen-stacks/main/repository.json"


# -- PRELOAD REFERENCES --
# These allow us to talk to the nodes we created in the editor
@onready var page_projects = $AppLayout/Content/PageProjects
@onready var page_engine = $AppLayout/Content/PageEngine
@onready var page_tools = $AppLayout/Content/PageTools
@onready var page_settings = $AppLayout/Content/PageSettings

@onready var btn_projects = $AppLayout/Sidebar/VBoxContainer/BtnProjects
@onready var btn_engine = $AppLayout/Sidebar/VBoxContainer/BtnEngine
@onready var btn_tools = $AppLayout/Sidebar/VBoxContainer/BtnTools
@onready var btn_settings = $AppLayout/Sidebar/VBoxContainer/BtnSettings

@onready var project_path_line_edit = $AppLayout/Content/PageProjects/ProjectsControls/ProjectPathLineEdit
@onready var btn_browse_project = $AppLayout/Content/PageProjects/ProjectsControls/BrowseButton
@onready var btn_load_project = $AppLayout/Content/PageProjects/ProjectsControls/LoadButton
@onready var btn_new_project = $AppLayout/Content/PageProjects/ProjectsControls/NewButton
@onready var lbl_project_status = $AppLayout/Content/PageProjects/ProjectsStatusLabel
@onready var lbl_offline_status = $AppLayout/Content/PageProjects/OfflineStatusLabel
@onready var tools_list = $AppLayout/Content/PageProjects/ToolsList
@onready var btn_launch_tool = $AppLayout/Content/PageProjects/ToolControlsContainer/LaunchButton
@onready var btn_seal_for_delivery = $AppLayout/Content/PageProjects/ToolControlsContainer/SealButton
@onready var btn_repair_environment = $AppLayout/Content/PageProjects/RepairButton
@onready var project_dir_dialog = $ProjectDirDialog

# Onboarding dialog
@onready var onboarding_dialog = $OnboardingWizardDialog

# Seal dialog nodes
@onready var seal_dialog = $SealDialog
@onready var seal_status_label = $SealDialog/VBoxContainer/StatusLabel
@onready var seal_output_label = $SealDialog/VBoxContainer/OutputLabel
@onready var seal_open_folder_button = $SealDialog/VBoxContainer/OpenFolderButton

# Hydration dialog nodes
@onready var hydration_dialog = $HydrationDialog
@onready var hydration_tools_list = $HydrationDialog/VBoxContainer/ToolsList
@onready var hydration_status_label = $HydrationDialog/VBoxContainer/StatusLabel

# Settings nodes
@onready var mirror_root_path = $AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootPath
@onready var mirror_root_browse_button = $AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootBrowseButton
@onready var mirror_root_reset_button = $AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootResetButton
@onready var mirror_repo_path = $AppLayout/Content/PageSettings/MirrorRepoContainer/MirrorRepoPath
@onready var mirror_repo_clear_button = $AppLayout/Content/PageSettings/MirrorRepoContainer/MirrorRepoClearButton
@onready var mirror_status_label = $AppLayout/Content/PageSettings/MirrorStatusLabel

var network_ui_nodes: Array = []

var projects_controller: ProjectsController
var hydration_controller: LibraryHydrationController
var layout_controller: LayoutController
var seal_controller: SealController
var onboarding_wizard: OnboardingWizard
var mirror_root_override: String = ""
var mirror_repository_url: String = ""
var settings_file_path: String = ""

## Resolves the base OGS data directory.
func _resolve_ogs_root_path() -> String:
	"""Returns the OGS root path, preferring LOCALAPPDATA on Windows."""
	var local_app_data = OS.get_environment("LOCALAPPDATA")
	if not local_app_data.is_empty():
		return local_app_data.path_join("OGS")
	return OS.get_user_data_dir().path_join("OGS")

func _ready():
	Logger.enable_console(true)
	Logger.set_level(Logger.Level.DEBUG)
	Logger.info("launcher_started", {"component": "app"})
	
	# Set up onboarding wizard for first-run experience
	var ogs_root_path = _resolve_ogs_root_path()
	var library_root_path = ogs_root_path.path_join("Library")
	onboarding_wizard = OnboardingWizard.new()
	onboarding_wizard.setup(get_tree(), library_root_path, onboarding_dialog, ogs_root_path)
	onboarding_wizard.wizard_completed.connect(_on_wizard_completed)
	
	# Show wizard on first run
	var should_show = onboarding_wizard.should_show_wizard()
	Logger.debug("onboarding_check", {"component": "onboarding", "should_show": should_show})
	if should_show:
		onboarding_wizard.show_wizard()
	
	# Set up layout controller for page navigation
	layout_controller = LayoutController.new()
	layout_controller.setup(
		btn_projects,
		btn_engine,
		btn_tools,
		btn_settings,
		page_projects,
		page_engine,
		page_tools,
		page_settings
	)
	layout_controller.page_changed.connect(_on_page_changed)

	# Projects page controller
	projects_controller = ProjectsController.new()
	projects_controller.setup(
		project_path_line_edit,
		btn_browse_project,
		btn_load_project,
		btn_new_project,
		lbl_project_status,
		lbl_offline_status,
		tools_list,
		btn_launch_tool,
		project_dir_dialog
	)
	projects_controller.offline_state_changed.connect(_on_offline_state_changed)
	
	# Set up seal controller for seal dialog
	seal_controller = SealController.new()
	seal_controller.setup(
		seal_dialog,
		seal_status_label,
		seal_output_label,
		seal_open_folder_button
	)
	seal_controller.seal_completed.connect(_on_seal_completed)
	
	# Set up hydration controller and wire signals
	hydration_controller = LibraryHydrationController.new()
	hydration_controller.setup(
		hydration_dialog,
		hydration_tools_list,
		hydration_status_label,
		hydration_dialog.get_ok_button(),
		"",  # mirror_url
		get_tree(),  # Pass scene tree reference for timers
		mirror_root_override,
		mirror_repository_url
	)
	
	# Wire hydration signals
	projects_controller.request_hydration.connect(_on_request_hydration)
	hydration_controller.hydration_finished.connect(_on_hydration_finished)
	
	# Wire repair button
	btn_repair_environment.pressed.connect(_on_repair_environment_pressed)
	
	# Wire seal button
	btn_seal_for_delivery.pressed.connect(_on_seal_button_pressed)
	
	# Listen for environment status changes
	projects_controller.environment_incomplete.connect(_on_environment_incomplete)
	projects_controller.environment_ready.connect(_on_environment_ready)

	# Settings for mirror configuration
	settings_file_path = OS.get_user_data_dir().path_join("ogs_launcher_settings.json")
	_load_mirror_settings()
	mirror_root_path.text_changed.connect(_on_mirror_root_text_changed)
	mirror_root_browse_button.pressed.connect(_on_mirror_root_browse_pressed)
	mirror_root_reset_button.pressed.connect(_on_mirror_root_reset_pressed)
	mirror_repo_path.text_changed.connect(_on_mirror_repo_text_changed)
	mirror_repo_clear_button.pressed.connect(_on_mirror_repo_clear_pressed)
	_update_mirror_status()

	_collect_network_ui_nodes()
	_apply_offline_ui(false)
	
	# Start on the Projects page
	layout_controller.navigate_to("projects")
	
	# Show onboarding wizard if first run
	if onboarding_wizard.should_show_wizard():
		onboarding_wizard.show_wizard()

func _on_page_changed(_page_name: String) -> void:
	"""Called when LayoutController changes pages."""
	# Page visibility is handled by LayoutController
	pass

func _collect_network_ui_nodes() -> void:
	"""Collects all UI nodes tagged as network-related."""
	var found: Array = []
	if is_inside_tree():
		found = get_tree().get_nodes_in_group("network_ui")
	# Fallback to metadata scan to catch nodes without group tags.
	var meta_found = _collect_network_ui_nodes_from(self)
	for node in meta_found:
		if not found.has(node):
			found.append(node)
	network_ui_nodes = found

func _collect_network_ui_nodes_from(root: Node) -> Array:
	"""Collects tagged nodes when the scene is not in a tree."""
	var found: Array = []
	if root.has_meta("network_ui") and root.get_meta("network_ui") == true:
		found.append(root)
	for child in root.get_children():
		found.append_array(_collect_network_ui_nodes_from(child))
	return found

func _on_offline_state_changed(active: bool, _reason: String) -> void:
	"""Disables network-related UI when offline is active."""
	_apply_offline_ui(active)

func _apply_offline_ui(active: bool) -> void:
	"""Applies offline UI state to tagged controls."""
	for node in network_ui_nodes:
		if node is BaseButton:
			var button := node as BaseButton
			button.disabled = active
			button.tooltip_text = "Disabled in offline mode." if active else ""
## Signal handler: when ProjectsController requests hydration.
func _on_request_hydration(missing_tools: Array) -> void:
	"""Shows the hydration dialog with list of missing tools."""
	hydration_controller.start_hydration(missing_tools)
	hydration_dialog.popup_centered()

## Signal handler: when hydration completes.
func _on_hydration_finished(success: bool, message: String) -> void:
	"""Re-validates the project environment after hydration."""
	projects_controller.on_hydration_complete(success, message)

## Signal handler: repair button pressed.
func _on_repair_environment_pressed() -> void:
	"""User clicked the 'Repair Environment' button."""
	projects_controller.request_repair_environment()

## Signal handler: environment is incomplete.
func _on_environment_incomplete(_missing_tools: Array) -> void:
	"""Shows the repair button and disables seal when tools are missing."""
	btn_repair_environment.visible = true
	var offline_active = OfflineEnforcer.is_offline()
	btn_repair_environment.disabled = offline_active
	if offline_active:
		btn_repair_environment.tooltip_text = "Disabled in offline mode."
		btn_repair_environment.remove_theme_color_override("font_color")
	else:
		# Color repair button orange to indicate action needed
		btn_repair_environment.add_theme_color_override("font_color", Color.ORANGE)
		btn_repair_environment.tooltip_text = ""
	# Disable seal button when environment is incomplete
	btn_seal_for_delivery.disabled = true
	btn_seal_for_delivery.tooltip_text = "Repair environment first to seal project."

## Signal handler: environment is complete.
func _on_environment_ready() -> void:
	"""Hides the repair button and re-enables seal when all tools are available."""
	btn_repair_environment.visible = false
	# Reset repair button color to default
	btn_repair_environment.remove_theme_color_override("font_color")
	# Re-enable seal button when environment is complete
	btn_seal_for_delivery.disabled = false
	btn_seal_for_delivery.tooltip_text = ""

## Signal handler: seal for delivery button pressed.
func _on_seal_button_pressed() -> void:
	"""User clicked the 'Seal for Delivery' button."""
	var current_project_path = projects_controller.current_project_dir
	seal_controller.seal_for_delivery(current_project_path)

## Signal handler: seal operation completed.
func _on_seal_completed(_success: bool, _zip_path: String) -> void:
	"""Seal controller finished sealing project."""
	# SealController handles all UI updates
	# This is just a notification point for future extensions
	pass
## Settings Methods

## Loads the mirror root setting from disk.
func _load_mirror_settings() -> void:
	"""Loads saved mirror settings from the settings file."""
	if FileAccess.file_exists(settings_file_path):
		var file = FileAccess.open(settings_file_path, FileAccess.READ)
		if file != null:
			var json_text = file.get_as_text()
			var data = JSON.parse_string(json_text)
			if data != null and typeof(data) == TYPE_DICTIONARY:
				mirror_root_override = String(data.get("mirror_root", ""))
				if data.has("remote_repository_url"):
					mirror_repository_url = String(data.get("remote_repository_url", ""))
				else:
					mirror_repository_url = DEFAULT_REMOTE_REPO_URL
				mirror_root_path.text = mirror_root_override
				mirror_repo_path.text = mirror_repository_url
				return
	# No saved setting found, use defaults
	mirror_root_override = ""
	mirror_repository_url = DEFAULT_REMOTE_REPO_URL
	mirror_root_path.text = ""
	mirror_repo_path.text = mirror_repository_url

## Saves the mirror root setting to disk.
func _save_mirror_settings() -> void:
	"""Saves the current mirror settings to disk."""
	var data = {
		"mirror_root": mirror_root_override,
		"remote_repository_url": mirror_repository_url,
		"timestamp": Time.get_ticks_msec()
	}
	var json_text = JSON.stringify(data)
	var file = FileAccess.open(settings_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(json_text)
		Logger.info("mirror_settings_saved", {"component": "settings"})

## Called when mirror root text changes.
func _on_mirror_root_text_changed(new_text: String) -> void:
	"""Updates mirror root override when text changes."""
	mirror_root_override = new_text
	_save_mirror_settings()
	_update_mirror_status()
	# Update hydration controller with new mirror root
	if hydration_controller != null:
		hydration_controller.update_mirror_root(mirror_root_override)

## Called when browse button is pressed.
func _on_mirror_root_browse_pressed() -> void:
	"""Opens file dialog to select mirror root directory."""
	var dialog = FileDialog.new()
	dialog.title = "Select Mirror Root Directory"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.dir_selected.connect(func(path: String):
		mirror_root_override = path
		mirror_root_path.text = path
		_save_mirror_settings()
		_update_mirror_status()
		if hydration_controller != null:
			hydration_controller.update_mirror_root(mirror_root_override)
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)

## Called when reset button is pressed.
func _on_mirror_root_reset_pressed() -> void:
	"""Resets mirror root to default."""
	mirror_root_override = ""
	mirror_root_path.text = ""
	_save_mirror_settings()
	_update_mirror_status()
	if hydration_controller != null:
		hydration_controller.update_mirror_root("")

## Called when mirror repository URL text changes.
func _on_mirror_repo_text_changed(new_text: String) -> void:
	"""Updates remote repository URL when text changes."""
	mirror_repository_url = new_text.strip_edges()
	_save_mirror_settings()
	_update_mirror_status()
	if hydration_controller != null:
		hydration_controller.update_remote_repository_url(mirror_repository_url)

## Called when mirror repository URL reset button is pressed.
func _on_mirror_repo_clear_pressed() -> void:
	"""Resets the remote repository URL setting to the default."""
	mirror_repository_url = DEFAULT_REMOTE_REPO_URL
	mirror_repo_path.text = mirror_repository_url
	_save_mirror_settings()
	_update_mirror_status()
	if hydration_controller != null:
		hydration_controller.update_remote_repository_url(mirror_repository_url)

## Updates the mirror status indicator.
func _update_mirror_status() -> void:
	"""Updates the mirror status label based on current settings."""
	var resolver = MirrorPathResolverScript.new()
	var effective_root = mirror_root_override if not mirror_root_override.is_empty() else resolver.get_mirror_root()
	var has_local_repo = false
	if not effective_root.is_empty() and DirAccess.dir_exists_absolute(effective_root):
		var repo_path = effective_root.path_join("repository.json")
		has_local_repo = FileAccess.file_exists(repo_path)

	if has_local_repo:
		mirror_status_label.text = "Mirror status: Local mirror ready"
		mirror_status_label.modulate = Color.GREEN
		return

	if not mirror_repository_url.is_empty():
		mirror_status_label.text = "Mirror status: Remote repository configured"
		mirror_status_label.modulate = Color(0.3, 0.6, 1.0, 1.0)
		return

	if mirror_root_override.is_empty():
		mirror_status_label.text = "Mirror status: Using default location"
		mirror_status_label.modulate = Color.GRAY
		return

	if DirAccess.dir_exists_absolute(mirror_root_override):
		mirror_status_label.text = "Mirror status: Directory exists, but repository.json not found"
		mirror_status_label.modulate = Color.YELLOW
		return

	mirror_status_label.text = "Mirror status: Directory does not exist"
	mirror_status_label.modulate = Color.RED

## Signal handler: onboarding wizard completed.
func _on_wizard_completed(success: bool, message: String) -> void:
	"""Called when onboarding wizard completes."""
	if success:
		Logger.info("wizard_startup_complete", {"component": "onboarding", "message": message})
	else:
		Logger.warn("wizard_startup_failed", {"component": "onboarding", "message": message})
