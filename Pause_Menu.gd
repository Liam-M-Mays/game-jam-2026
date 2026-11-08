class_name PauseMenu
extends Control

const MAIN_MENU_SCENE := "res://main_menu.tscn"

@export var resume_button: TextureButton
@export var menu_button: TextureButton
@export var quit_button: TextureButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(close)
	quit_button.pressed.connect(get_tree().quit)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)


func open() -> void:
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
