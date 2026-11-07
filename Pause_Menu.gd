class_name PauseMenu
extends Control
## Attach to the PauseMenu node inside the HUD.

const MAIN_MENU_SCENE := "res://main_menu.tscn"  # <- change to your menu scene's path

@export var resume_button: TextureButton
@export var back_button: TextureButton
@export var menu_button: TextureButton


func _ready() -> void:
	# ALWAYS = this menu keeps working while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(close)
	back_button.pressed.connect(close)  # same as RESUME for now
	menu_button.pressed.connect(_on_menu_pressed)


func open() -> void:
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false


func _on_menu_pressed() -> void:
	# Pausing survives scene changes, so unpause first or the menu will be frozen.
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
