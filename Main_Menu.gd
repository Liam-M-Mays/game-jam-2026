extends Control

const GAME_SCENE := preload("res://assets/Scenes/Levels/game.tscn")
const GROUND_SCENE := "res://assets/Scenes/Levels/ground.tscn"

@export var start_button: TextureButton
## Starts the village on the ground world instead of on the giant.
@export var ground_button: Button
@export var credits_button: TextureButton
@export var quit_button: TextureButton
## CREDITS opens this menu on its credits page.
@export var settings_menu: SettingsMenu
## Shows the version from Project Settings > Application > Config > Version.
@export var version_label: Label


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	ground_button.pressed.connect(_on_ground_pressed)
	start_button.add_to_group(InputMode.DEFAULT_FOCUS)
	InputMode.focus_default.call_deferred()
	credits_button.pressed.connect(settings_menu.open_credits)
	quit_button.pressed.connect(get_tree().quit)
	if version_label:
		version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))


func _on_start_pressed() -> void:
	GameState.new_game()
	SceneFader.change_scene(GAME_SCENE)


func _on_ground_pressed() -> void:
	GameState.new_game()
	SceneFader.change_scene(GROUND_SCENE)
