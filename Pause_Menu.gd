class_name PauseMenu
extends Control

@export var resume_button: TextureButton
@export var quit_button: TextureButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(close)
	quit_button.pressed.connect(get_tree().quit)


func open() -> void:
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false
