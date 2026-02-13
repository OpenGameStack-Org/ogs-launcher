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

func _ready():
	# Connect the button signals to our function
	btn_projects.pressed.connect(_on_tab_pressed.bind(page_projects))
	btn_engine.pressed.connect(_on_tab_pressed.bind(page_engine))
	btn_tools.pressed.connect(_on_tab_pressed.bind(page_tools))
	btn_settings.pressed.connect(_on_tab_pressed.bind(page_settings))
	
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
