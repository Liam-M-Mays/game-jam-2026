extends PanelContainer
class_name WorkerPanel
## Opens when a building with worker slots is clicked. Its arrows add or remove a worker,
## between 0 and the building's `worker_slots`. Escape or a click anywhere else closes it.

const GROUP := &"worker_panel"

@export var title : Label
@export var count_label : Label
@export var remove_button : Button
@export var add_button : Button

var _building : Building = null

func _ready() -> void:
	add_to_group(GROUP)
	hide()
	remove_button.pressed.connect(_on_arrow_pressed.bind(false))
	add_button.pressed.connect(_on_arrow_pressed.bind(true))

## Shows the panel for `building`. Buildings call this through the group when clicked.
func open(building : Building) -> void:
	close()
	_building = building
	_building.set_selected(true)
	title.text = building.display_name()
	_refresh()
	show()

func close() -> void:
	if is_instance_valid(_building):
		_building.set_selected(false)
	_building = null
	hide()

func _unhandled_input(event : InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		close()

func _on_arrow_pressed(add : bool) -> void:
	if add:
		_building.add_worker_slot()
	else:
		_building.remove_worker_slot()
	_refresh()

func _refresh() -> void:
	count_label.text = "%d / %d" % [_building.wanted_workers, _building.worker_slots]
	remove_button.disabled = _building.wanted_workers <= 0
	add_button.disabled = _building.wanted_workers >= _building.worker_slots
