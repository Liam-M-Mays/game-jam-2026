extends PanelContainer
class_name WorkerPanel
## Opens when a finished building is clicked. Its arrows add or remove a worker, between 0 and the
## building's `worker_slots`, and a building with no slots hides them. Its Remove button asks first.
## Escape or a click anywhere else closes it.

const GROUP := &"worker_panel"

@export var title : Label
@export var note_label : Label
@export var count_label : Label
@export var remove_button : Button
@export var add_button : Button
@export var arrows : Control
@export var remove_building_button : Button
@export var confirm_row : Control
@export var confirm_label : Label
@export var confirm_button : Button
@export var keep_button : Button

var _building : Building = null
## The building the arrows set. A farm or a silo gives its barn, and a hut gives null.
var _workers_of : Building = null

func _ready() -> void:
	add_to_group(GROUP)
	hide()
	remove_button.pressed.connect(_on_arrow_pressed.bind(false))
	add_button.pressed.connect(_on_arrow_pressed.bind(true))
	remove_building_button.pressed.connect(_show_confirm.bind(true))
	keep_button.pressed.connect(_show_confirm.bind(false))
	confirm_button.pressed.connect(_on_confirm_pressed)

## Shows the panel for `building`. Buildings call this through the group when clicked.
func open(building : Building) -> void:
	close()
	_building = building
	_workers_of = building.worker_building()
	_building.set_selected(true)
	title.text = building.display_name()
	note_label.text = building.note()
	note_label.visible = not note_label.text.is_empty()
	arrows.visible = _workers_of != null
	remove_building_button.disabled = not building.can_remove()
	remove_building_button.tooltip_text = "" if building.can_remove() else "The %s cannot be removed" % building.display_name()
	_show_confirm(false)
	_refresh()
	show()

func close() -> void:
	if is_instance_valid(_building):
		_building.set_selected(false)
	_building = null
	_workers_of = null
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
		_workers_of.add_worker_slot()
	else:
		_workers_of.remove_worker_slot()
	_refresh()

func _show_confirm(on : bool) -> void:
	confirm_label.text = _building.remove_question()
	remove_building_button.visible = not on
	confirm_row.visible = on

func _on_confirm_pressed() -> void:
	var building := _building
	close()
	building.remove_building()

func _refresh() -> void:
	if _workers_of == null:
		return
	count_label.text = "%d / %d" % [_workers_of.wanted_workers, _workers_of.worker_slots]
	remove_button.disabled = _workers_of.wanted_workers <= 0
	add_button.disabled = _workers_of.wanted_workers >= _workers_of.worker_slots
