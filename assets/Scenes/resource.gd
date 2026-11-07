extends Sprite2D
class_name resource

const WOBBLE_DURATION := 0.25

@export var area : Area2D
@export var wobble_interval := 0.6
@export var wobbles_to_break := 4
@export var wobble_angle := 8.0

var cells : Array = []

var _wobbles := 0
var _mine_queued := false

func _ready() -> void:
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)

func _on_area_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_left_click()
			else:
				_on_left_release()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_on_right_click()
			else:
				_on_right_release()
				
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)

func _on_left_click() -> void:
	if _mine_queued:
		return
	_mine_queued = true
	JobSystem.add_mine_job(self)

func _on_left_release() -> void:
	pass

func _on_right_click() -> void:
	pass

func _on_right_release() -> void:
	pass

func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	pass

func _on_mouse_entered() -> void:
	modulate = Color.RED
	for cell in cells:
		cell.set_trans(0.5)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
	for cell in cells:
		cell.set_trans(0)
		
# One mining hit. Returns true on the hit that breaks this resource.
func mine() -> bool:
	_wobbles += 1
	var tween = create_tween()
	var step = WOBBLE_DURATION / 4
	tween.tween_property(self, "rotation_degrees", wobble_angle, step)
	tween.tween_property(self, "rotation_degrees", -wobble_angle, step * 2)
	tween.tween_property(self, "rotation_degrees", 0.0, step)
	if _wobbles < wobbles_to_break:
		return false
	tween.tween_callback(_break)
	return true

func _break() -> void:
	for cell in cells:
		cell.resource = null
		cell.set_trans(0)
	queue_free()
