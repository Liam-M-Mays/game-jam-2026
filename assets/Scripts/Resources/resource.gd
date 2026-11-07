extends Sprite2D
class_name resource

const WOBBLE_DURATION := 0.25

@export var area : Area2D
@export var wobble_interval := 0.6
@export var wobbles_to_break := 4
@export var wobble_angle := 3.0
@export var squash_amount := 0.15
@export var wood_yield := 0
@export var stone_yield := 0

const FLASH_SHADER := preload("res://assets/Shaders/flash.gdshader")
const FLASH_DURATION := 0.12
const BREAK_HOLD := 0.06

var _flash_tween : Tween

const SQUASH_DURATION := 0.2

var _squash_tween : Tween
var _base_scale : Vector2

const BREAK = preload("res://assets/Scenes/Resources/break.tscn")

var cells : Array = []

var _wobbles := 0
var _mine_queued := false

func _ready() -> void:
	_base_scale = scale
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	material = mat

func _flash(color := Color.WHITE) -> void:
	if _flash_tween:
		_flash_tween.kill()
	material.set_shader_parameter("flash_color", color)
	material.set_shader_parameter("flash", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(material, "shader_parameter/flash", 0.0, FLASH_DURATION)

func _squash() -> void:
	if _squash_tween:
		_squash_tween.kill()
	scale = _base_scale * Vector2(1.0 + squash_amount, 1.0 - squash_amount)
	_squash_tween = create_tween()
	_squash_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(self, "scale", _base_scale, SQUASH_DURATION)


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

func mine() -> bool:
	_squash()
	_wobbles += 1
	if _wobbles >= wobbles_to_break:
		_final_flash()
		return true
	_flash()
	var tween = create_tween()
	var step = WOBBLE_DURATION / 4
	tween.tween_property(self, "rotation_degrees", wobble_angle, step)
	tween.tween_property(self, "rotation_degrees", -wobble_angle, step * 2)
	tween.tween_property(self, "rotation_degrees", 0.0, step)
	return false

func _final_flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	material.set_shader_parameter("flash", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(BREAK_HOLD)
	_flash_tween.tween_callback(_break)

func _break() -> void:
	var bre = BREAK.instantiate()
	bre.position = position + offset * _base_scale
	bre.scale = _base_scale
	bre.z_index = z_index
	get_parent().add_child(bre)
	bre.animation_finished.connect(bre.queue_free)
	bre.play("break")
	Inventory.add(wood_yield, stone_yield)
	for cell in cells:
		cell.resource = null
		cell.set_trans(0)
	queue_free()
