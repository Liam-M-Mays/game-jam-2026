extends Sprite2D
class_name GridObject

const OUTLINE_SHADER := preload("res://assets/Shaders/outline.gdshader")
const FLASH_DURATION := 0.12
const SHAKE_DURATION := 0.3
const SHAKE_DISTANCE := 1.5
const REJECT_COLOR := Color(1, 0.15, 0.15)
const HOVER_CELL_ALPHA := 0.5

@export var area : Area2D
@export_range(1, 4) var footprint := 1
@export var hoverable := true

var grid : Grid
var cells : Array[Cell] = []

var _base_scale : Vector2
var _base_offset : Vector2
var _tweens := {}

func _ready() -> void:
	_base_scale = scale
	_base_offset = offset
	material = ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	_refresh_region()
	texture_changed.connect(_refresh_region)
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_set_hovered.bind(true))
	area.mouse_exited.connect(_set_hovered.bind(false))

func _on_clicked() -> void:
	pass

func set_selected(on : bool) -> void:
	material.set_shader_parameter("selected", on)

func flash(color := Color.WHITE) -> void:
	_start_flash(color).tween_property(material, "shader_parameter/flash", 0.0, FLASH_DURATION)

func reject() -> void:
	flash(REJECT_COLOR)
	offset.x = _base_offset.x
	var tween := _tween(&"shake")
	var step := SHAKE_DURATION / 5.0
	for x in [1.0, -1.0, 0.5, -0.5, 0.0]:
		tween.tween_property(self, "offset:x", _base_offset.x + x * SHAKE_DISTANCE, step)

func spawn_effect(scene : PackedScene, z_offset := 0) -> void:
	var effect : AnimatedSprite2D = scene.instantiate()
	effect.position = position + _base_offset * _base_scale
	effect.scale = _base_scale
	effect.z_index = z_index + z_offset
	effect.animation_finished.connect(effect.queue_free)
	get_parent().add_child(effect)
	effect.play()

func _start_flash(color : Color) -> Tween:
	material.set_shader_parameter("flash_color", color)
	material.set_shader_parameter("flash", 1.0)
	return _tween(&"flash")

func _tween(key : StringName) -> Tween:
	if _tweens.has(key):
		_tweens[key].kill()
	_tweens[key] = create_tween()
	return _tweens[key]

func _set_hovered(on : bool) -> void:
	if not hoverable:
		return
	material.set_shader_parameter("hovered", on)
	for cell in cells:
		cell.highlight(HOVER_CELL_ALPHA if on else 0.0)

func _on_area_input_event(_viewport : Viewport, event : InputEvent, _shape_idx : int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_clicked()

func _refresh_region() -> void:
	var region := Vector4(0, 0, 1, 1)
	if texture is AtlasTexture and texture.atlas:
		var size : Vector2 = texture.atlas.get_size()
		var r : Rect2 = texture.region
		region = Vector4(r.position.x / size.x, r.position.y / size.y, r.end.x / size.x, r.end.y / size.y)
	material.set_shader_parameter("region_rect", region)
