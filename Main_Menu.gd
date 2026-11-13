extends Control

const GAME_SCENE := preload("res://assets/Scenes/Levels/game.tscn")
const GROUND_SCENE := "res://assets/Scenes/Levels/ground.tscn"

@export var start_button: TextureButton
## Starts the village on the ground world instead of on the giant.
@export var ground_button: Button
@export var credits_button: TextureButton
@export var quit_button: TextureButton
@export var credits_panel: Control
@export var credits_back_button: TextureButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	ground_button.pressed.connect(_on_ground_pressed)
	credits_button.pressed.connect(credits_panel.show)
	credits_back_button.pressed.connect(credits_panel.hide)
	quit_button.pressed.connect(get_tree().quit)
	credits_panel.hide()


func _on_start_pressed() -> void:
	GameState.new_game()
	get_tree().change_scene_to_packed(GAME_SCENE)


func _on_ground_pressed() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file(GROUND_SCENE)
