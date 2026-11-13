extends RefCounted
class_name Meeple
## One meeple as plain data. Grid owns it, ticks it once a frame and gives it one canvas item to draw on.
## Positions are in Grid's space, apart from `global_position`.

const WANDER_ATTEMPTS := 8
const CARRY_FRAMES := { "wood": 2, "stone": 4 }
const CARRY_HEAD_OFFSET := -0.5
const DOUBLE_CARRY_FRAMES := { "wood": 3, "stone": 5 }
const DOUBLE_CARRY_HEAD_OFFSET := -1.0
const SORT_BIAS := Vector2(0, 3)
const IDLE_CHECK_INTERVAL := 0.5
const WANDER_JITTER := Vector2(12, 6)
const PATH_CHECKS := 8
const FEET_OFFSET := Vector2(0, 1)
const TOPPLE_REBOUND := 0.2
const TOPPLE_REBOUND_TIME := 0.08
## How fast the bounce clock runs per second of game time. The jam's bounce ran this fast at speed x1.
const BOUNCE_RATE := 1000.0 / 60.0
## A standing meeple only redraws when its stretch moves by this much, so it costs no call most frames.
const STAND_STRETCH_STEP := 0.01

var grid : Grid
var job : Job
## The building this meeple works for. Null for a builder, who takes only the player's jobs.
var workplace : Building
var position : Vector2
var global_position : Vector2:
	get:
		return grid.to_global(position)

var _look : MeepleLook
var _item : RID
## Two canvas items behind `_item` that draw the outline, while the meeple is highlighted. Empty otherwise.
var _outline : Array[RID] = []
var _frame := 0
var _head_offset := 0.0
var _body_color := Color.from_hsv(randf(), 0.8, 0.9)
var _rotation := 0.0
var _stretch := 1.0
var _bounce := 0.0
var _target : Vector2
var _stop_cells : Array[Cell] = []
## How close to its target a meeple must be before it can stand on one of `_stop_cells`.
var _stop_reach := -1.0
var _wandering := false
var _wander_home : Vector2
var _wander_pause := 0.0
var _wander_building : Building = null
var _idle_check := 0.0
var _dead_time := -1.0
var _feet : Vector2
var _arm : Vector2
var _lying := 0.0
var _fall_from := 0.0

func _init(owner : Grid, look : MeepleLook, at : Vector2) -> void:
	grid = owner
	_look = look
	position = at
	_target = at
	_bounce = randf() * TAU / look.stretch_speed
	_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_item, owner.get_canvas_item())
	RenderingServer.canvas_item_set_z_index(_item, look.z_index)
	carry()
	_show()

## Frees the canvas item. Grid calls this when it leaves the game.
func free_item() -> void:
	set_highlighted(false)
	if _item.is_valid():
		RenderingServer.free_rid(_item)
	_item = RID()

## Outlines the meeple, the way a selected building is outlined. Only the few meeples this is on pay for it.
func set_highlighted(on : bool) -> void:
	if on == not _outline.is_empty() or (on and not _item.is_valid()):
		return
	if not on:
		for item in _outline:
			RenderingServer.free_rid(item)
		_outline.clear()
		return
	for i in range(2):
		var item := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(item, _item)
		RenderingServer.canvas_item_set_draw_behind_parent(item, true)
		_outline.append(item)
	_redraw()

func move_to(world_pos : Vector2, stop_cells : Array[Cell] = []) -> void:
	_target = grid.to_local(world_pos) + SORT_BIAS
	_stop_cells = stop_cells
	_stop_reach = -1.0
	for cell in stop_cells:
		_stop_reach = maxf(_stop_reach, _target.distance_to(cell.position) + grid.cell_reach())

func stop() -> void:
	_target = position
	_stop_cells = []
	_stop_reach = -1.0

## True at the target, or on one of the cells `move_to` gave. It looks up the cell only when the meeple
## is near enough to be on one, because that lookup is the cost of thousands of walking meeples.
func has_arrived() -> bool:
	var distance := _target.distance_to(position)
	if distance <= 1:
		return true
	if distance <= _stop_reach and grid.cell_at(global_position) in _stop_cells:
		stop()
		return true
	return false

func abandon_job() -> void:
	JobSystem.requeue(job, self)
	job = null
	stop()
	JobSystem.worker_freed(self)

## True when a player's job may take this meeple: it is an alive builder with no job.
func is_free() -> bool:
	return _dead_time < 0.0 and job == null and workplace == null

## Starts `new_job`. JobSystem calls this when it matches the two.
func take_job(new_job : Job) -> void:
	job = new_job
	_wandering = false
	job.start(self)

## Sends a worker back to being a builder. Its building's remove arrow calls this.
func leave_workplace() -> void:
	if job != null:
		job.abort(self)
	job = null
	workplace = null
	stop()
	JobSystem.worker_freed(self)

func die() -> void:
	VillageAudio.play(&"hurt", global_position)
	if job != null and workplace != null:
		job.abort(self)
	elif job != null:
		JobSystem.requeue(job, self)
	job = null
	if workplace != null:
		workplace.lose_worker(self)
	JobSystem.remove_worker(self)
	_stretch = 1.0
	_arm = FEET_OFFSET * _look.scale
	_feet = position + _arm.rotated(_rotation)
	_fall_from = _rotation
	_lying = (1.0 if randf() < 0.5 else -1.0) * PI * 0.5
	_dead_time = 0.0

func carry(kind := "", amount := 1) -> void:
	if amount >= 2 and DOUBLE_CARRY_FRAMES.has(kind):
		_frame = DOUBLE_CARRY_FRAMES[kind]
		_head_offset = DOUBLE_CARRY_HEAD_OFFSET
	else:
		_frame = CARRY_FRAMES.get(kind, 0)
		_head_offset = CARRY_HEAD_OFFSET if CARRY_FRAMES.has(kind) else 0.0
	_redraw()

func _redraw() -> void:
	_look.draw(_item, _body_color, _frame, _head_offset)
	if not _outline.is_empty():
		_look.draw_outline(_outline, _body_color, _frame, _head_offset)

## Moves, works and draws for one frame. Returns false once a dead meeple has faded out and freed its item.
func tick(delta : float) -> bool:
	if _dead_time >= 0.0:
		return _tick_dead(delta)
	_bounce += delta * BOUNCE_RATE
	var moving := not has_arrived()
	if moving:
		position = position.move_toward(_target, delta * (_look.wander_speed if _wandering else _look.speed))
		_stretch = 1 + sin(_bounce * _look.stretch_speed) * _look.y_stretch
		_rotation = deg_to_rad(sin(_bounce * _look.wobble_speed) * _look.wobble)
		_show()
	else:
		var stretch := 1 + snappedf(sin(_bounce * _look.stretch_speed) * _look.y_stretch * 0.5, STAND_STRETCH_STEP)
		if stretch != _stretch or _rotation != 0.0:
			_stretch = stretch
			_rotation = 0.0
			_show()
	_work(delta)
	return true

func _show() -> void:
	var scale := Vector2(_look.scale.x, _look.scale.y * _stretch)
	RenderingServer.canvas_item_set_transform(_item, Transform2D(_rotation, scale, 0.0, position))

func _tick_dead(delta : float) -> bool:
	_dead_time += delta
	var fall_end := _look.topple_time + TOPPLE_REBOUND_TIME * 2
	if _dead_time - delta <= fall_end:
		_rotation = _topple_angle(minf(_dead_time, fall_end))
		position = _feet - _arm.rotated(_rotation)
		_show()
	var fade := (_dead_time - fall_end - _look.corpse_linger) / _look.fade_time
	if fade >= 1.0:
		free_item()
		return false
	if fade > 0.0:
		RenderingServer.canvas_item_set_modulate(_item, Color(1, 1, 1, 1.0 - fade))
	return true

func _topple_angle(t : float) -> float:
	var rebound := _lying - signf(_lying) * TOPPLE_REBOUND
	if t < _look.topple_time:
		var x := t / _look.topple_time
		return lerpf(_fall_from, _lying, x * x)
	t -= _look.topple_time
	if t < TOPPLE_REBOUND_TIME:
		return lerpf(_lying, rebound, sin(t / TOPPLE_REBOUND_TIME * PI * 0.5))
	t -= TOPPLE_REBOUND_TIME
	return lerpf(rebound, _lying, 1.0 - cos(minf(t / TOPPLE_REBOUND_TIME, 1.0) * PI * 0.5))

func _work(delta : float) -> void:
	if job == null:
		if workplace != null:
			job = _ask_for_work(delta)
		if job == null:
			_wander(delta)
			return
		_wandering = false
		job.start(self)
	if not job.update(self, delta):
		return
	if workplace == null:
		JobSystem.finish(job)
		JobSystem.worker_freed(self)
	job = null

## A worker asks its building for the next task at most every IDLE_CHECK_INTERVAL.
func _ask_for_work(delta : float) -> Job:
	_idle_check -= delta
	if _idle_check > 0.0:
		return null
	# A little more or less each time, so workers who started together do not all ask in the same frame.
	_idle_check = IDLE_CHECK_INTERVAL * randf_range(0.5, 1.5)
	return workplace.find_work(self)

func _wander(delta : float) -> void:
	if not has_arrived():
		return
	if not _wandering:
		_wandering = true
		_wander_home = position
		_wander_building = _nearest_building()
		_wander_pause = randf_range(_look.wander_pause_min, _look.wander_pause_max)
	_wander_pause -= delta
	if _wander_pause > 0:
		return
	_wander_pause = randf_range(_look.wander_pause_min, _look.wander_pause_max)
	if not is_instance_valid(_wander_building) or randf() < _look.building_hop_chance:
		_wander_building = _pick_building()
	if _wander_building != null:
		var spot = _spot_near(_wander_building)
		if spot != null:
			_target = spot
			return
	for i in range(WANDER_ATTEMPTS):
		var spot := _wander_home + Vector2.from_angle(randf() * TAU) * randf_range(_look.wander_radius * 0.25, _look.wander_radius)
		if grid.cell_at(grid.to_global(spot)) != null:
			_target = spot
			return

func _spot_near(building : Building):
	var cells := grid.cells_around(building, _look.wander_ring)
	cells.shuffle()
	var fallback = null
	var fallback_dist := INF
	for i in range(mini(cells.size(), WANDER_ATTEMPTS)):
		var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * WANDER_JITTER
		var spot : Vector2 = cells[i].position + jitter
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
		var cell := grid.cell_at(grid.to_global(point))
		if cell != null and cell.occupant is Building:
			return false
	return true

func _nearest_building() -> Building:
	var best : Building = null
	var best_dist := INF
	for building in grid.get_tree().get_nodes_in_group(Building.COMPLETED_GROUP):
		var dist := global_position.distance_squared_to(building.global_position)
		if dist < best_dist:
			best_dist = dist
			best = building
	return best

func _pick_building() -> Building:
	var buildings := grid.get_tree().get_nodes_in_group(Building.COMPLETED_GROUP)
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
