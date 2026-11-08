extends Sprite2D
class_name Meeple

const WANDER_ATTEMPTS := 8
const CARRY_FRAMES := { "wood": 2, "stone": 4 }
const CARRY_HEAD_OFFSET := -0.5
const SORT_BIAS := Vector2(0, 3)

@export var speed := 100
@export var y_stretch := 0.1
@export var stretch_speed := 0.25
@export var wobble := 10
@export var wobble_speed := 1.5
@export var wander_radius := 60.0
@export var wander_speed := 30
@export var wander_pause_min := 1.0
@export var wander_pause_max := 3.5

@export var grid : Grid

var job : Job

var _target : Vector2
var _stop_cells : Array[Cell] = []
var _wandering := false
var _wander_home : Vector2
var _wander_pause := 0.0

@onready var _base_scale_y := scale.y
@onready var _head : AnimatedSprite2D = $head

func _enter_tree() -> void:
	JobSystem.add_worker(self)

func _exit_tree() -> void:
	JobSystem.remove_worker(self)

func _ready() -> void:
	self_modulate = Color.from_hsv(randf(), 0.8, 0.9)
	_target = position

func move_to(world_pos : Vector2, stop_cells : Array[Cell] = []) -> void:
	_target = get_parent().to_local(world_pos) + SORT_BIAS
	_stop_cells = stop_cells

func stop() -> void:
	_target = position
	_stop_cells = []

func has_arrived() -> bool:
	if not _stop_cells.is_empty() and grid.cell_at(global_position) in _stop_cells:
		stop()
	return _target.distance_to(position) <= 1

func die() -> void:
	set_process(false)
	if job != null:
		JobSystem.requeue(job, self)
		job = null
	JobSystem.remove_worker(self)
	queue_free()

func carry(kind := "") -> void:
	_head.frame = CARRY_FRAMES.get(kind, 0)
	_head.offset.y = CARRY_HEAD_OFFSET if CARRY_FRAMES.has(kind) else 0.0

func _physics_process(delta : float) -> void:
	var t := Time.get_ticks_msec() * delta
	var moving := not has_arrived()
	if moving:
		position += (_target - position).normalized() * delta * (wander_speed if _wandering else speed)
	scale.y = _base_scale_y * (1 + sin(t * stretch_speed) * y_stretch * (1.0 if moving else 0.5))
	rotation_degrees = sin(t * wobble_speed) * wobble if moving else 0.0

func _process(delta : float) -> void:
	if job == null:
		job = JobSystem.take()
		if job == null:
			_wander(delta)
			return
		_wandering = false
		job.start(self)
	if job.update(self, delta):
		JobSystem.finish(job)
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
		if grid.cell_at(get_parent().to_global(spot)) != null:
			_target = spot
			return
