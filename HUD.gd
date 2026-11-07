extends CanvasLayer
## Attach to the HUD CanvasLayer (hud.tscn), then instance hud.tscn into your game scene.

@export var stone_label: Label
@export var wood_label: Label
@export var meeple_label: Label
@export var hunger_bar: TextureProgressBar
@export var build_button: TextureButton
@export var build_menu: BuildMenu
@export var pause_menu: PauseMenu


func _ready() -> void:
	# ALWAYS so Esc still works while paused. ToastFeed opts back into pausing on its own.
	process_mode = Node.PROCESS_MODE_ALWAYS

	hunger_bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	hunger_bar.min_value = 0.0
	hunger_bar.max_value = GameState.MAX_HUNGER
	hunger_bar.step = 0.0  # no rounding = smooth drain
	hunger_bar.value = GameState.hunger

	GameState.resources_changed.connect(_update_counters)
	GameState.hunger_changed.connect(_on_hunger_changed)
	GameState.starved.connect(_on_starved)
	build_button.pressed.connect(_on_build_pressed)

	_update_counters()


func _unhandled_input(event: InputEvent) -> void:
	# ui_cancel is Esc by default.
	if event.is_action_pressed("ui_cancel"):
		if build_menu.visible:
			build_menu.close()
		elif pause_menu.visible:
			pause_menu.close()
		else:
			pause_menu.open()
		get_viewport().set_input_as_handled()


func _update_counters() -> void:
	stone_label.text = str(GameState.stone)
	wood_label.text = str(GameState.wood)
	meeple_label.text = str(GameState.meeple)


func _on_hunger_changed(value: float) -> void:
	hunger_bar.value = value


func _on_starved() -> void:
	GameState.toast("Your people are starving!")


func _on_build_pressed() -> void:
	if pause_menu.visible:
		return
	if build_menu.visible:
		build_menu.close()
	else:
		build_menu.open()
