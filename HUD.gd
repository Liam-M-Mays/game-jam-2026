extends CanvasLayer

enum HungerBand { STARVING, FED, THRIVING }

const SPEED_KEY := KEY_F
const CLEAR_JOBS_KEY := KEY_C
const FIRST_TIP_DELAY := 2.0
const ROTATION_DELAY_MIN := 60.0
const ROTATION_DELAY_MAX := 90.0
const DEATH_SCREEN_DELAY := 1.0
const DEATH_SCREEN_FADE := 2.0
const DEATH_SCREEN_BLACK := 2.0
const OPENING_TIP_GAP := 15.0
## The builders number turns this red, the toast warning colour, when every meeple works in a building.
const NO_BUILDERS_COLOR := Color("ff6b5b")
const ZOOM_OUT_FACT := "Have you zoomed out all the way yet?"
const PAUSE_BUILDING_TIP := "Right-click a building under construction to pause it, and right-click again to resume"
const OPENING_TIPS := [
	"Tap on trees and stones to begin harvesting resources",
	"Use WASD to move the camera and the mouse wheel to zoom",
	"Picking berries will feed your meeple",
	"Click the build button to start expanding your meeple village",
	PAUSE_BUILDING_TIP,
]

const TIPS := [
	"Press 'F' to toggle game speed",
	"Berry bushes disappear after collecting from them 3 times",
	"Keep your hunger bar up to keep your meeples happy (and alive)",
	"You can upgrade your Town Hall level by increasing your Meeple population",
	"Hover over build sites to see what materials it still needs",
	"Use the number keys to place new buildings without opening the build menu",
	PAUSE_BUILDING_TIP,
]

const FUN_FACTS := [
	"This game was created for The 2026 UNCC Fall 49er Game Jam!",
	"Each Meeple has a real human soul trapped inside of them",
	"Bananas are berries, but strawberries aren't",
	"Oxford University is older than the Aztec Empire",
	ZOOM_OUT_FACT,
	"Antarctica is technically a desert",
	"Sharks are older than trees",
	"Did you know that cashews came from a fruit?",
	"The Great Meeple War took place from 1508 to 1521",
	"Today I saw a balloon",
	"This game has no affiliation with The Mighty Meeple Retail Business",
]

@export var build_system: BuildSystem
@export var counters: Control
@export var stone_label: Label
@export var wood_label: Label
@export var food_label: Label
@export var meeple_label: Label
@export var hunger_bar: TextureProgressBar
@export var build_button: TextureButton
@export var build_menu: BuildMenu
@export var pause_menu: PauseMenu
@export var death_screen: PauseMenu
@export var speed_button: Button
@export var jobs_label: Label
@export var clear_jobs_button: Button
@export var workers_label: Label
@export var builders_label: Label
## The giant's camera. The HUD hides when it is zoomed all the way out. Empty on the ground, where the HUD always stays.
@export var camera: CameraControls

var _building_scene: PackedScene
var _last_meeple_count := 0
var _last_builders := 0
var _last_food := 0
var _last_hunger_band := HungerBand.THRIVING
var _upgrade_was_ready := false
var _game_over := false
var _deck: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if counters:
		_ignore_mouse(counters)
	Inventory.changed.connect(_refresh_counters)
	Inventory.changed.connect(_check_food_empty)
	GameState.hunger_changed.connect(_check_hunger_band)
	JobSystem.changed.connect(_refresh_counters)
	JobSystem.changed.connect(_check_meeples)
	JobSystem.changed.connect(_refresh_roles)
	Population.all_meeples_died.connect(_on_all_meeples_died)
	_last_meeple_count = JobSystem.workers.size()
	_last_food = Inventory.count("food")
	_last_hunger_band = _hunger_band(GameState.hunger)
	_refresh_counters()
	_refresh_roles()
	_setup_hunger_bar()
	_setup_building()
	_setup_speed_button()
	if clear_jobs_button:
		clear_jobs_button.focus_mode = Control.FOCUS_NONE
		clear_jobs_button.pressed.connect(JobSystem.clear_waiting_player_jobs)
	_watch_existing_town_halls.call_deferred()
	_wait(FIRST_TIP_DELAY).connect(_show_opening_tip.bind(0))


func _process(_delta: float) -> void:
	if camera:
		visible = not camera.is_zoomed_out() or get_tree().paused
	if speed_button:
		speed_button.disabled = get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == SPEED_KEY:
		if not get_tree().paused:
			GameState.cycle_speed()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == CLEAR_JOBS_KEY:
		if not get_tree().paused:
			JobSystem.clear_waiting_player_jobs()
			get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel") or _game_over:
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
		stone_label.text = "%d/%d" % [Inventory.available("stone"), Inventory.room("stone")]
	if wood_label:
		wood_label.text = "%d/%d" % [Inventory.available("wood"), Inventory.room("wood")]
	if food_label:
		food_label.text = "%d/%d food" % [Inventory.available("food"), Inventory.food_cap()]
	if meeple_label:
		meeple_label.text = "%d / %d" % [JobSystem.workers.size(), Population.capacity()]
	var waiting := JobSystem.waiting_player_jobs()
	if jobs_label:
		jobs_label.text = "%d jobs waiting" % waiting
	if clear_jobs_button:
		clear_jobs_button.disabled = waiting == 0


## Workers are meeples in a building's slot, builders are the rest. When the last builder goes into
## a slot, the builders number turns red and one warning says so. It warns again only after a builder came back.
func _refresh_roles() -> void:
	var meeples := JobSystem.workers.size()
	var in_slots := JobSystem.count_in_slots()
	var builders := meeples - in_slots
	if workers_label:
		workers_label.text = "%d %s" % [in_slots, "worker" if in_slots == 1 else "workers"]
	if builders_label:
		builders_label.text = "%d %s" % [builders, "builder" if builders == 1 else "builders"]
		if builders == 0 and meeples > 0:
			builders_label.add_theme_color_override("font_color", NO_BUILDERS_COLOR)
		else:
			builders_label.remove_theme_color_override("font_color")
	if builders == 0 and _last_builders > 0 and meeples > 0:
		GameState.warn("No builders left! Every meeple works in a building. Click one and use its arrows to free a meeple")
	_last_builders = builders


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
		build_system.build_started.connect(_on_build_started)
		build_system.building_completed.connect(_on_building_completed)
		build_system.placement_failed.connect(_on_placement_failed)
	if build_menu:
		build_menu.build_system = build_system
	if build_button:
		build_button.pressed.connect(_on_build_pressed)


func _setup_speed_button() -> void:
	GameState.speed_changed.connect(_show_speed)
	if speed_button:
		speed_button.focus_mode = Control.FOCUS_NONE
		speed_button.pressed.connect(GameState.cycle_speed)
	_show_speed(GameState.speed)


func _show_speed(value: float) -> void:
	if speed_button:
		speed_button.text = "x%s" % str(value).trim_suffix(".0")


func _on_build_started(scene: PackedScene) -> void:
	_building_scene = scene
	if build_menu and build_menu.visible:
		build_menu.close()


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
	if building is TownHall:
		_watch_town_hall(building)
	if building is Hut:
		GameState.toast("%s finished! A new meeple arrived" % building.display_name())
	else:
		GameState.toast("%s finished!" % building.display_name())


func _on_placement_failed(reason: BuildSystem.PlacementError, hint: String) -> void:
	match reason:
		BuildSystem.PlacementError.CANT_AFFORD:
			var building_name := BuildMenu.display_name(_building_scene) if _building_scene else "that"
			GameState.warn("You need more materials to build %s" % building_name)
		BuildSystem.PlacementError.BLOCKED:
			GameState.warn("Can't build there")
		BuildSystem.PlacementError.OUT_OF_AREA:
			GameState.warn(hint)


func _watch_existing_town_halls() -> void:
	for node in get_tree().get_nodes_in_group(Building.COMPLETED_GROUP):
		if node is TownHall:
			_watch_town_hall(node)
	_check_upgrade_ready()


func _watch_town_hall(hall: TownHall) -> void:
	if not hall.upgraded.is_connected(_on_town_hall_upgraded):
		hall.upgraded.connect(_on_town_hall_upgraded)


func _check_upgrade_ready() -> void:
	var hall := TownHall.find_town_hall()
	var can_upgrade := hall != null and hall.can_upgrade()
	if can_upgrade and not _upgrade_was_ready:
		GameState.toast("You have enough meeples to upgrade your Town Hall! Open the build menu to upgrade it")
	_upgrade_was_ready = can_upgrade


func _on_town_hall_upgraded(level: int) -> void:
	_upgrade_was_ready = false
	_check_upgrade_ready.call_deferred()
	GameState.toast("Town Hall reached level %d!" % level)
	if not build_menu:
		return
	var names := build_menu.unlocked_names(level)
	if not names.is_empty():
		GameState.toast("New buildings unlocked: " + ", ".join(names))


func _check_meeples() -> void:
	var count := JobSystem.workers.size()
	if count < _last_meeple_count:
		GameState.warn("A meeple has died, watch your hunger bar!")
	_last_meeple_count = count
	_check_upgrade_ready()


func _on_all_meeples_died() -> void:
	_game_over = true
	Music.fade_out_game_over()
	_wait(DEATH_SCREEN_DELAY).connect(_show_death_screen)


func _show_death_screen() -> void:
	if build_menu:
		build_menu.close()
	if death_screen:
		death_screen.fade_in(DEATH_SCREEN_FADE, DEATH_SCREEN_BLACK)


func _check_food_empty() -> void:
	var food := Inventory.count("food")
	if _last_food > 0 and food == 0:
		GameState.warn("You're out of food! Pick berries or plant farms to gather more")
	_last_food = food


func _hunger_band(value: float) -> HungerBand:
	if value < Population.RULES.starve_below:
		return HungerBand.STARVING
	if value <= Population.RULES.grow_above:
		return HungerBand.FED
	return HungerBand.THRIVING


func _check_hunger_band(value: float) -> void:
	if JobSystem.workers.is_empty():
		return
	var band := _hunger_band(value)
	if band == _last_hunger_band:
		return
	_last_hunger_band = band
	match band:
		HungerBand.STARVING:
			GameState.warn("Meeples are starving! Get more food")
		HungerBand.FED:
			GameState.toast("Meeples are fed, but won't reproduce")
		HungerBand.THRIVING:
			GameState.toast("Meeples are well fed and can reproduce")


func _show_opening_tip(index: int) -> void:
	GameState.tip(OPENING_TIPS[index])
	if index + 1 < OPENING_TIPS.size():
		_wait(OPENING_TIP_GAP).connect(_show_opening_tip.bind(index + 1))
	else:
		_wait(randf_range(ROTATION_DELAY_MIN, ROTATION_DELAY_MAX)).connect(_show_next_in_rotation)


func _show_next_in_rotation() -> void:
	if _deck.is_empty():
		_refill_deck()
	var entry: Dictionary = _deck.pop_back()
	if entry["fact"]:
		GameState.fact(entry["text"])
	else:
		GameState.tip(entry["text"])
	_wait(randf_range(ROTATION_DELAY_MIN, ROTATION_DELAY_MAX)).connect(_show_next_in_rotation)


func _refill_deck() -> void:
	for text in TIPS:
		_deck.append({"text": text, "fact": false})
	for text in FUN_FACTS:
		if text == ZOOM_OUT_FACT and camera == null:
			continue
		_deck.append({"text": text, "fact": true})
	_deck.shuffle()


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, false, false, true).timeout


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
