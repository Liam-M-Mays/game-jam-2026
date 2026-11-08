extends CanvasLayer

@export var build_system: BuildSystem
@export var counters: Control
@export var stone_label: Label
@export var wood_label: Label
@export var food_label: Label
@export var meeple_label: Label
@export var job_label: Label
@export var hunger_bar: TextureProgressBar
@export var build_button: TextureButton
@export var build_menu: BuildMenu
@export var pause_menu: PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if counters:
		_ignore_mouse(counters)
	Inventory.changed.connect(_refresh_counters)
	JobSystem.changed.connect(_refresh_counters)
	JobSystem.job_rejected.connect(func(_job): GameState.toast("Too many jobs queued"))
	GameState.starved.connect(func(): GameState.toast("Your people are starving!"))
	_refresh_counters()
	_setup_hunger_bar()
	_setup_building()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if build_menu and build_menu.visible:
		build_menu.close()
	elif pause_menu and pause_menu.visible:
		pause_menu.close()
	elif pause_menu:
		pause_menu.open()
	else:
		return
	get_viewport().set_input_as_handled()


func _refresh_counters() -> void:
	if stone_label:
		stone_label.text = str(Inventory.count("stone"))
	if wood_label:
		wood_label.text = str(Inventory.count("wood"))
	if food_label:
		food_label.text = str(Inventory.count("food"))
	if meeple_label:
		meeple_label.text = "%d / %d" % [JobSystem.workers.size(), Population.capacity()]
	if job_label:
		job_label.text = "%d / %d" % [JobSystem.job_count(), JobSystem.capacity()]


func _setup_hunger_bar() -> void:
	if not hunger_bar:
		return
	hunger_bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	hunger_bar.min_value = 0.0
	hunger_bar.max_value = GameState.MAX_HUNGER
	hunger_bar.step = 0.0
	hunger_bar.value = GameState.hunger
	GameState.hunger_changed.connect(func(value: float): hunger_bar.value = value)


func _setup_building() -> void:
	if build_system:
		build_system.building_placed.connect(func(_b: Building): GameState.toast("Building placed"))
		build_system.building_completed.connect(_on_building_completed)
		build_system.placement_failed.connect(_on_placement_failed)
	if build_menu:
		build_menu.build_system = build_system
	if build_button:
		build_button.pressed.connect(_on_build_pressed)


func _on_build_pressed() -> void:
	if not build_menu or (pause_menu and pause_menu.visible):
		return
	if build_menu.visible:
		build_menu.close()
		return
	if build_system and build_system.is_building():
		build_system.end_build()
	build_menu.open()


func _on_building_completed(building: Building) -> void:
	if building is Hut:
		GameState.toast("Hut finished! A new meeple arrived")
	else:
		GameState.toast("Building finished!")


func _on_placement_failed(reason: BuildSystem.PlacementError) -> void:
	match reason:
		BuildSystem.PlacementError.CANT_AFFORD:
			GameState.toast("Not enough resources")
		BuildSystem.PlacementError.QUEUE_FULL:
			GameState.toast("Too many jobs queued")
		BuildSystem.PlacementError.BLOCKED:
			GameState.toast("Can't build there")


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
