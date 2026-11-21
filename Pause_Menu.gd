class_name PauseMenu
extends Control

const MAIN_MENU_SCENE := "res://Main_Menu.tscn"

@export var resume_button: TextureButton
@export var menu_button: TextureButton
@export var quit_button: TextureButton
@export var restart_on_resume := false
@export var dim: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.add_to_group(InputMode.DEFAULT_FOCUS)
	resume_button.pressed.connect(_on_retry_pressed if restart_on_resume else close)
	quit_button.pressed.connect(SaveGame.save_and_quit)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)


func open() -> void:
	show()
	get_tree().paused = true
	InputMode.focus_default.call_deferred()


func fade_in(seconds: float, black_seconds: float) -> void:
	modulate.a = 0.0
	open()
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	tween.tween_property(self, "modulate:a", 1.0, seconds)
	if dim:
		tween.tween_property(dim, "color:a", 1.0, black_seconds)


func close() -> void:
	hide()
	get_tree().paused = false


func _on_retry_pressed() -> void:
	GameState.new_game()
	SceneFader.change_scene()


func _on_menu_pressed() -> void:
	SaveGame.save_now()
	SceneFader.change_scene(MAIN_MENU_SCENE)
