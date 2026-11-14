extends Control

const GAME_SCENE := preload("res://assets/Scenes/Levels/game.tscn")
const GROUND_SCENE := "res://assets/Scenes/Levels/ground.tscn"

@export var start_button: TextureButton
## Shown only when there is a saved village. Its art is set in code from UiArt.
@export var continue_button: TextureButton
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
	UiArt.apply(continue_button, "continue_gray")
	continue_button.size = continue_button.custom_minimum_size
	continue_button.visible = SaveGame.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	# Added after Start, so a controller lands on Continue when there is a save.
	continue_button.add_to_group(InputMode.DEFAULT_FOCUS)
	InputMode.focus_default.call_deferred()
	credits_button.pressed.connect(settings_menu.open_credits)
	quit_button.pressed.connect(get_tree().quit)
	if version_label:
		version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))


func _on_continue_pressed() -> void:
	if not SaveGame.continue_game():
		continue_button.hide()


func _on_start_pressed() -> void:
	_new_game(GAME_SCENE)


func _on_ground_pressed() -> void:
	_new_game(GROUND_SCENE)


## Starts a new village. With a save, it asks first, because the new game replaces the saved one.
func _new_game(level: Variant) -> void:
	if SaveGame.has_save():
		var dialog := ConfirmDialog.ask(self, "Start a new game?\nThis replaces your saved village.", "start", "back")
		await dialog.confirmed
		SaveGame.delete_save()
	GameState.new_game()
	SceneFader.change_scene(level)
