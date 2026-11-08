extends Control

const GAME_SCENE := "res://assets/Scenes/Levels/game.tscn"

@export var start_button: TextureButton
@export var credits_button: TextureButton
@export var quit_button: TextureButton
@export var credits_panel: Control
@export var credits_back_button: TextureButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	credits_button.pressed.connect(credits_panel.show)
	credits_back_button.pressed.connect(credits_panel.hide)
	quit_button.pressed.connect(get_tree().quit)
	credits_panel.hide()


func _on_start_pressed() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)
