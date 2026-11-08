extends Sprite2D
class_name Meeple

const WANDER_ATTEMPTS := 8
const CARRY_FRAMES := { "wood": 2, "stone": 4 }
const CARRY_HEAD_OFFSET := -0.5
const SORT_BIAS := Vector2(0, 3)
const IDLE_CHECK_INTERVAL := 0.5
const WANDER_JITTER := Vector2(12, 6)
const PATH_CHECKS := 8
const FEET_OFFSET := Vector2(0, 1)
const TOPPLE_REBOUND := 0.2
const TOPPLE_REBOUND_TIME := 0.08

@export var speed := 100
@export var y_stretch := 0.1
@export var stretch_speed := 0.25
@export var wobble := 10
@export var wobble_speed := 1.5
@export var wander_radius := 60.0
@export var wander_speed := 30
@export var wander_pause_min := 1.0
@export var wander_pause_max := 3.5
@export var wander_ring := 2
@export var building_hop_chance := 0.15
@export var topple_time := 0.45
@export var corpse_linger := 0.6
@export var fade_time := 0.8

@export var grid : Grid

var job : Job

var _target : Vector2
var _stop_cells : Array[Cell] = []
var _wandering := false
var _wander_home : Vector2
var _wander_pause := 0.0
var _wander_building : Building = null
var _idle_check := 0.0

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
	set_physics_process(false)
	if job != null:
		JobSystem.requeue(job, self)
		job = null
	JobSystem.remove_worker(self)
	_topple()

func _topple() -> void:
	scale.y = _base_scale_y
	var arm := FEET_OFFSET * scale
	var feet := position + arm.rotated(rotation)
	var side := 1.0 if randf() < 0.5 else -1.0
	var lying := side * PI * 0.5
	var rebound := lying - side * TOPPLE_REBOUND
	var lean := _lean.bind(feet, arm)
	var tween := create_tween()
	tween.tween_method(lean, rotation, lying, topple_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(lean, lying, rebound, TOPPLE_REBOUND_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(lean, rebound, lying, TOPPLE_REBOUND_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_interval(corpse_linger)
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)

func _lean(angle : float, feet : Vector2, arm : Vector2) -> void:
	rotation = angle
	position = feet - arm.rotated(angle)

func carry(kind := "") -> void:
	_head.frame = CARRY_FRAMES.get(kind, 0)
	_head.offset.y = CARRY_HEAD_OFFSET if CARRY_FRAMES.has(kind) else 0.0

func _physics_process(delta : float) -> void:
	var t := Time.get_ticks_msec() * delta
	var moving := not has_arrived()
	if moving:
		position = position.move_toward(_target, delta * (wander_speed if _wandering else speed))
	scale.y = _base_scale_y * (1 + sin(t * stretch_speed) * y_stretch * (1.0 if moving else 0.5))
	rotation_degrees = sin(t * wobble_speed) * wobble if moving else 0.0

func _process(delta : float) -> void:
	if job is IdleJob and JobSystem.has_pending():
		JobSystem.requeue(job, self)
		job = null
	if job == null:
		job = JobSystem.take()
		if job == null:
			job = _ask_for_idle_job(delta)
		if job == null:
			_wander(delta)
			return
		_wandering = false
		job.start(self)
	if job.update(self, delta):
		JobSystem.finish(job)
		job = null

func _ask_for_idle_job(delta : float) -> IdleJob:
	_idle_check -= delta
	if _idle_check > 0.0:
		return null
	_idle_check = IDLE_CHECK_INTERVAL
	return JobSystem.find_idle_job(self)

func _wander(delta : float) -> void:
	if not has_arrived():
		return
	if not _wandering:
		_wandering = true
		_wander_home = position
		_wander_building = _nearest_building()
		_wander_pause = randf_range(wander_pause_min, wander_pause_max)
	_wander_pause -= delta
	if _wander_pause > 0:
		return
	_wander_pause = randf_range(wander_pause_min, wander_pause_max)
	if not is_instance_valid(_wander_building) or randf() < building_hop_chance:
		_wander_building = _pick_building()
	if _wander_building != null:
		var spot = _spot_near(_wander_building)
		if spot != null:
			_target = spot
			return
	for i in range(WANDER_ATTEMPTS):
		var spot := _wander_home + Vector2.from_angle(randf() * TAU) * randf_range(wander_radius * 0.25, wander_radius)
		if grid.cell_at(get_parent().to_global(spot)) != null:
			_target = spot
			return

func _spot_near(building : Building):
	var cells := grid.cells_around(building, wander_ring)
	cells.shuffle()
	var fallback = null
	var fallback_dist := INF
	for i in range(mini(cells.size(), WANDER_ATTEMPTS)):
		var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * WANDER_JITTER
		var spot : Vector2 = get_parent().to_local(grid.to_global(cells[i].position)) + jitter
		if _clear_path(spot):
			return spot
		var dist := position.distance_squared_to(spot)
		if dist < fallback_dist:
			fallback_dist = dist
			fallback = spot
	return fallback

func _clear_path(to : Vector2) -> bool:
	for i in range(1, PATH_CHECKS + 1):
		var point : Vector2 = position.lerp(to, float(i) / PATH_CHECKS)
		var cell := grid.cell_at(get_parent().to_global(point))
		if cell != null and cell.occupant is Building:
			return false
	return true

func _nearest_building() -> Building:
	var best : Building = null
	var best_dist := INF
	for building in get_tree().get_nodes_in_group(Building.COMPLETED_GROUP):
		var dist := global_position.distance_squared_to(building.global_position)
		if dist < best_dist:
			best_dist = dist
			best = building
	return best

func _pick_building() -> Building:
	var buildings := get_tree().get_nodes_in_group(Building.COMPLETED_GROUP)
	if buildings.is_empty():
		return null
	var weights : Array[float] = []
	var total := 0.0
	for building in buildings:
		var steps := global_position.distance_to(building.global_position) / 100.0
		var weight := 1.0 / (1.0 + steps * steps)
		weights.append(weight)
		total += weight
	var roll := randf() * total
	for i in range(buildings.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return buildings[i]
	return buildings.back()
