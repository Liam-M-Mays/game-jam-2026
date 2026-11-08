extends CanvasLayer

const FIRST_TIP_DELAY := 2.0
const LOW_FOOD := 5
const LOW_HUNGER := 50.0

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

var _building_scene: PackedScene
var _last_meeple_count := 0
var _tips_shown := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if counters:
		_ignore_mouse(counters)
	Inventory.changed.connect(_refresh_counters)
	Inventory.changed.connect(_check_resource_tips)
	JobSystem.changed.connect(_refresh_counters)
	JobSystem.changed.connect(_check_meeple_deaths)
	JobSystem.job_rejected.connect(func(_job): GameState.warn("Job queue is full"))
	GameState.hunger_changed.connect(_check_hunger_tip)
	_last_meeple_count = JobSystem.workers.size()
	_refresh_counters()
	_setup_hunger_bar()
	_setup_building()
	get_tree().create_timer(FIRST_TIP_DELAY, false).timeout.connect(
		_show_tip.bind("collect", "Tap on trees and stones to collect resources"))


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
		build_system.build_started.connect(func(scene: PackedScene): _building_scene = scene)
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
		GameState.toast("%s finished! A new meeple arrived" % building.display_name())
	else:
		GameState.toast("%s finished!" % building.display_name())


func _on_placement_failed(reason: BuildSystem.PlacementError) -> void:
	match reason:
		BuildSystem.PlacementError.CANT_AFFORD:
			var building_name := BuildMenu.display_name(_building_scene) if _building_scene else "that"
			GameState.warn("You need more materials to build %s" % building_name)
		BuildSystem.PlacementError.QUEUE_FULL:
			GameState.warn("Job queue is full")
		BuildSystem.PlacementError.BLOCKED:
			GameState.warn("Can't build there")


func _check_meeple_deaths() -> void:
	var count := JobSystem.workers.size()
	if count < _last_meeple_count:
		GameState.warn("A meeple has died, watch your hunger bar!")
	_last_meeple_count = count


func _check_resource_tips() -> void:
	if Inventory.count("wood") > 0 or Inventory.count("stone") > 0:
		_show_tip("build", "Use the tool button to build structures")
	if Inventory.count("food") <= LOW_FOOD:
		_show_tip("food", "Tap on bushes to get food")


func _check_hunger_tip(value: float) -> void:
	if value <= LOW_HUNGER:
		_show_tip("hunger", "Keep your hunger bar up to keep your meeples happy")


func _show_tip(id: String, text: String) -> void:
	if _tips_shown.has(id):
		return
	_tips_shown[id] = true
	GameState.tip(text)


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
