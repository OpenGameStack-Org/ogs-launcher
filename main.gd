extends Control


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

# Seal dialog nodes
@onready var seal_dialog = $SealDialog
@onready var seal_status_label = $SealDialog/VBoxContainer/StatusLabel
@onready var seal_output_label = $SealDialog/VBoxContainer/OutputLabel
@onready var seal_open_folder_button = $SealDialog/VBoxContainer/OpenFolderButton

# Hydration dialog nodes
@onready var hydration_dialog = $HydrationDialog
@onready var hydration_tools_list = $HydrationDialog/VBoxContainer/ToolsList
@onready var hydration_status_label = $HydrationDialog/VBoxContainer/StatusLabel

var network_ui_nodes: Array = []

var projects_controller: ProjectsController
var hydration_controller: LibraryHydrationController
var layout_controller: LayoutController
var seal_controller: SealController

func _ready():
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
		get_tree()  # Pass scene tree reference for timers
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

	_collect_network_ui_nodes()
	_apply_offline_ui(false)
	
	# Start on the Projects page
	layout_controller.navigate_to("projects")

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
	"""Shows the repair button when tools are missing."""
	btn_repair_environment.visible = true

## Signal handler: environment is complete.
func _on_environment_ready() -> void:
	"""Hides the repair button when all tools are available."""
	btn_repair_environment.visible = false

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
