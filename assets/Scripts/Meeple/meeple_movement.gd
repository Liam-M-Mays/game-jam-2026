extends Sprite2D
class_name Meeple

@export var speed := 100
@export var y_stretch := 0.1
@export var stretch_speed := 0.25
@export var wobble := 10
@export var wobble_speed := 1.5
@export var wander_radius := 60.0
@export var wander_speed := 30
@export var wander_pause_min := 1.0
@export var wander_pause_max := 3.5

const WANDER_ATTEMPTS := 8
const HEAD_FRAMES_CARRY_ONE := { "wood": 2, "stone": 4 }
const HEAD_OFFSET_CARRY_ONE := -0.5
## Stand a hair below targets so y-sort draws us in front of what we're working on.
const SORT_BIAS := Vector2(0, 3)

var target : Vector2
var job : Job

var _stop_cells : Array = []
var _wandering := false
var _wander_home : Vector2
var _wander_pause := 0.0

@onready var _base_scale_y := scale.y
@onready var _grid = $"../Grid"
@onready var _head : AnimatedSprite2D = $head

func get_random_hsv_color() -> Color:
	var random_hue: float = randf()
	var saturation: float = 0.8
	var value: float = 0.9
	return Color(random_hue, saturation, value)
	
func _ready() -> void:
	self_modulate = get_random_hsv_color()

## Walk to pos. If stop_cells is given, stop as soon as we step onto any of them.
func move_to(pos : Vector2, stop_cells : Array = []) -> void:
	target = get_parent().to_local(pos) + SORT_BIAS
	_stop_cells = stop_cells

func has_arrived() -> bool:
	if not _stop_cells.is_empty() and _grid.cell_at(get_parent().to_global(position)) in _stop_cells:
		target = position
		_stop_cells = []
	return target.distance_to(position) <= 1

func set_carrying(kind : String) -> void:
	_head.frame = HEAD_FRAMES_CARRY_ONE[kind]
	_head.offset.y = HEAD_OFFSET_CARRY_ONE

func clear_carrying() -> void:
	_head.frame = 0
	_head.offset.y = 0.0

func _physics_process(delta: float) -> void:
	if has_arrived():
		scale.y = _base_scale_y * (1 + sin(Time.get_ticks_msec() * stretch_speed* delta) * y_stretch * 0.5)
		set_rotation_degrees(0)
	else:
		var offset_vector = (target - position).normalized()
		position += offset_vector*delta*(wander_speed if _wandering else speed)
		scale.y = _base_scale_y * (1 + sin(Time.get_ticks_msec() * stretch_speed* delta) * y_stretch)
		set_rotation_degrees(sin(Time.get_ticks_msec() * delta * wobble_speed) * wobble)

func _process(delta : float) -> void:
	if job == null:
		job = JobSystem.take_job()
		if job == null:
			_wander(delta)
			return
		_wandering = false
		job.start(self)
	if job.update(self, delta):
		job = null

func _wander(delta : float) -> void:
	if not has_arrived():
		return
	if not _wandering:
		_wandering = true
		_wander_home = position
		_wander_pause = randf_range(wander_pause_min, wander_pause_max)
	_wander_pause -= delta
	if _wander_pause > 0:
		return
	_wander_pause = randf_range(wander_pause_min, wander_pause_max)
	for i in range(WANDER_ATTEMPTS):
		var spot := _wander_home + Vector2.from_angle(randf() * TAU) * randf_range(wander_radius * 0.25, wander_radius)
		if _grid.cell_at(get_parent().to_global(spot)) != null:
			target = spot
			return
