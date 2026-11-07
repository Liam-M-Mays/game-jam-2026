class_name BuildMenu
extends Control
## Attach to the BuildMenu node inside the HUD.

## Emitted when the player picks a building they can afford (cost is already paid).
## Connect this to whatever handles placing buildings in the world.
signal building_chosen(building: Dictionary)

## Placeholder list. Edit names/costs freely; add more entries the same way.
const BUILDINGS := [
	{"id": "hut", "name": "Hut", "wood": 10, "stone": 0},
	{"id": "storehouse", "name": "Storehouse", "wood": 15, "stone": 10},
	{"id": "wall", "name": "Stone Wall", "wood": 0, "stone": 20},
]

@export var building_list: Container  # a VBoxContainer or GridContainer
@export var back_button: TextureButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	back_button.pressed.connect(close)
	GameState.resources_changed.connect(_refresh)
	_create_buttons()


func open() -> void:
	_refresh()
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false


func _create_buttons() -> void:
	for building in BUILDINGS:
		var button := Button.new()
		button.text = "%s   %d wood / %d stone" % [building["name"], building["wood"], building["stone"]]
		button.set_meta("building", building)
		button.pressed.connect(_on_building_pressed.bind(building))
		building_list.add_child(button)


func _refresh() -> void:
	for button in building_list.get_children():
		var building: Dictionary = button.get_meta("building")
		# Greys out what you can't afford. To hide those instead, use:
		# button.visible = GameState.can_afford(building)
		button.disabled = not GameState.can_afford(building)


func _on_building_pressed(building: Dictionary) -> void:
	if GameState.spend(building):
		GameState.toast("Built %s" % building["name"])
		building_chosen.emit(building)
		close()
