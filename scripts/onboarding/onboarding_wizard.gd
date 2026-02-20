## OnboardingWizard: First-run welcome and default stack bootstrap.
##
## Manages the first-run experience:
##   1. Detects if this is a first run
##   2. Shows welcome screen with default stack information
##   3. Handles one-click initialization of Godot 4.3 + Blender 4.2
##   4. Marks wizard as complete
##
## Usage:
##   var wizard = OnboardingWizard.new()
##   wizard.setup(scene_tree, library_root)
##   if wizard.should_show_wizard():
##       wizard.show_wizard()

extends RefCounted
class_name OnboardingWizard

signal wizard_completed(success: bool, message: String)

var wizard_complete_flag_path: String = ""
var library_root: String = ""
var dialog: AcceptDialog = null
var status_label: Label = null
var default_stack_label: Label = null
var start_button: Button = null
var skip_button: Button = null
var scene_tree: SceneTree = null

## Initializes the onboarding wizard.
## Parameters:
##   tree (SceneTree): Scene tree for creating nodes
##   library_root_path (String): Path where libraries are stored
func setup(tree: SceneTree, library_root_path: String) -> void:
	"""Sets up the wizard with required references."""
	scene_tree = tree
	library_root = library_root_path
	wizard_complete_flag_path = OS.get_user_data_dir().path_join("ogs_wizard_complete.txt")

## Returns true if the wizard should be shown (first run).
func should_show_wizard() -> bool:
	"""Returns true if this is a first run and wizard hasn't been completed."""
	# Check if wizard completion flag exists
	if FileAccess.file_exists(wizard_complete_flag_path):
		return false
	
	# Check if library root exists and has tools
	if DirAccess.dir_exists_absolute(library_root):
		var lib_dir = DirAccess.open(library_root)
		if lib_dir != null:
			lib_dir.list_dir_begin()
			var file_name = lib_dir.get_next()
			while file_name != "":
				if not file_name.starts_with("."):
					return false  # Found a tool directory, not first run
				file_name = lib_dir.get_next()
	
	return true

## Shows the wizard dialog.
func show_wizard() -> void:
	"""Creates and displays the wizard dialog."""
	if dialog == null:
		_create_wizard_dialog()
	
	if dialog:
		dialog.popup_centered_ratio(0.6)

## Marks the wizard as complete (won't show again).
func mark_complete() -> void:
	"""Writes completion flag to disk."""
	var file = FileAccess.open(wizard_complete_flag_path, FileAccess.WRITE)
	if file != null:
		file.store_string("completed")
		Logger.info("onboarding_wizard_completed", {"component": "onboarding"})

# Private: Creates the wizard dialog UI.
func _create_wizard_dialog() -> void:
	"""Creates the wizard dialog with UI elements."""
	dialog = AcceptDialog.new()
	dialog.title = "Welcome to Open Game Stack"
	dialog.size = Vector2i(600, 400)
	dialog.ok_button_text = "Start"
	
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	dialog.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Open Game Stack Launcher"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "First-Run Setup"
	subtitle.add_theme_font_size_override("font_size", 14)
	vbox.add_child(subtitle)
	
	# Welcome text
	var welcome = Label.new()
	welcome.autowrap_mode = TextServer.AUTOWRAP_WORD
	welcome.text = "Welcome! This wizard will help you set up the default frozen stack with essential tools."
	vbox.add_child(welcome)
	
	# Default stack info
	default_stack_label = Label.new()
	default_stack_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	default_stack_label.text = "Default Stack:\n• Godot v4.3 (Game Engine)\n• Blender v4.2 LTS (3D Modeling)\n\nThese tools will be downloaded to your central library."
	vbox.add_child(default_stack_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# Status label
	status_label = Label.new()
	status_label.text = "Ready to initialize."
	status_label.modulate = Color.GRAY
	vbox.add_child(status_label)
	
	# Buttons container
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(button_hbox)
	
	skip_button = Button.new()
	skip_button.text = "Skip for Now"
	skip_button.pressed.connect(_on_skip_pressed)
	button_hbox.add_child(skip_button)
	
	# Wire the Start button through the dialog
	var ok_button = dialog.get_ok_button()
	ok_button.text = "Start"
	ok_button.pressed.connect(_on_start_pressed)

## Signal handler: skip button pressed.
func _on_skip_pressed() -> void:
	"""User chose to skip wizard."""
	if dialog:
		dialog.hide()
	mark_complete()
	wizard_completed.emit(true, "Wizard skipped. You can always configure tools later.")

## Signal handler: start button pressed.
func _on_start_pressed() -> void:
	"""User chose to initialize default stack."""
	if status_label:
		status_label.text = "Initializing default stack..."
		status_label.modulate = Color.YELLOW
	
	# For now, just mark as complete and close
	# In Phase 3, this would trigger actual tool downloads
	_initialize_default_stack()

## Initializes the default Stack (Godot 4.3 + Blender 4.2).
func _initialize_default_stack() -> void:
	"""Prepares the library for default stack tools."""
	# Create library directory structure
	var lib_dir = library_root
	if not DirAccess.dir_exists_absolute(lib_dir):
		DirAccess.make_dir_recursive_absolute(lib_dir)
	
	# Create tool subdirectories
	var godot_dir = lib_dir.path_join("godot").path_join("4.3")
	var blender_dir = lib_dir.path_join("blender").path_join("4.2")
	
	# Ensure directories exist
	DirAccess.make_dir_recursive_absolute(godot_dir)
	DirAccess.make_dir_recursive_absolute(blender_dir)
	
	# Mark wizard complete
	mark_complete()
	
	if status_label:
		status_label.text = "Default stack initialized successfully!"
		status_label.modulate = Color.GREEN
	
	if dialog:
		dialog.hide()
	
	wizard_completed.emit(true, "Default stack initialized. Tools can be added via the mirror or repair workflow.")
	Logger.info("default_stack_initialized", {"component": "onboarding"})
