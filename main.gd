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
@onready var btn_launch_tool = $AppLayout/Content/PageProjects/LaunchButton
@onready var btn_repair_environment = $AppLayout/Content/PageProjects/RepairButton
@onready var project_dir_dialog = $ProjectDirDialog

# Hydration dialog nodes
@onready var hydration_dialog = $HydrationDialog
@onready var hydration_tools_list = $HydrationDialog/VBoxContainer/ToolsList
@onready var hydration_status_label = $HydrationDialog/VBoxContainer/StatusLabel

var network_ui_nodes: Array = []

var projects_controller: ProjectsController
var hydration_controller: LibraryHydrationController

func _ready():
	# Connect the button signals to our function
	btn_projects.pressed.connect(_on_tab_pressed.bind(page_projects))
	btn_engine.pressed.connect(_on_tab_pressed.bind(page_engine))
	btn_tools.pressed.connect(_on_tab_pressed.bind(page_tools))
	btn_settings.pressed.connect(_on_tab_pressed.bind(page_settings))

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
	
	# Listen for environment status changes
	projects_controller.environment_incomplete.connect(_on_environment_incomplete)
	projects_controller.environment_ready.connect(_on_environment_ready)

	_collect_network_ui_nodes()
	_apply_offline_ui(false)
	
	# Start on the Projects page
	_on_tab_pressed(page_projects)

func _on_tab_pressed(target_page: Control):
	# 1. Hide all pages
	page_projects.visible = false
	page_engine.visible = false
	page_tools.visible = false
	page_settings.visible = false
	
	# 2. Show the requested page
	target_page.visible = true

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