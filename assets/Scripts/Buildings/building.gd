extends GridObject
class_name Building

signal completed
signal missing_changed

const BUILD_EFFECT := preload("res://assets/Scenes/Effects/cloud.tscn")
const EMPTY_STAGE := -1
const BLUEPRINT_SHADER := preload("res://assets/Shaders/blueprint.gdshader")
const PREVIEW_OPACITY := 0.5

## Tick on if the sheet runs finished -> empty (left to right) instead of empty -> finished.
@export var reverse_frames := false
@export var build_frames := 0
## Cost of each build frame, in order. Entry i pays for frame i. Missing entries are free.
@export var frames : Array[BuildFrame] = []
## Resources that must be available before the building can be placed.
@export var min_to_start : Dictionary[String, int] = {}

## Total cost of all frames (read-only; edit the frames instead).
var costs : Dictionary[String, int]:
	get:
		return _sum_frame_costs()

var _built := EMPTY_STAGE
var _constructing := false
var _missing : Dictionary[String, int] = {}
var _requesting := false
var _banked : Dictionary[String, int] = {}
var _incoming : Dictionary[String, int] = {}
var _unposted : Array[HaulJob] = []
var _idle_job : IdleJob = null
var _blueprint : Sprite2D = null

func _ready() -> void:
	super()
	area.input_pickable = false
	if not frames.is_empty() and frames.size() != last_stage() + 1:
		push_warning("%s has %d frame costs but %d build frames" % [display_name(), frames.size(), last_stage() + 1])

## Call after the preview is in the tree (GridObject._ready sets the outline material).
func show_as_preview() -> void:
	_set_stage(last_stage())
	material = ShaderMaterial.new()
	material.shader = BLUEPRINT_SHADER
	material.set_shader_parameter("opacity", PREVIEW_OPACITY)

func set_preview_blocked(blocked : bool) -> void:
	material.set_shader_parameter("blocked", blocked)

func last_stage() -> int:
	return (build_frames if build_frames > 0 else hframes) - 1

func _set_stage(stage : int) -> void:
	stage = mini(stage, last_stage())
	# Hide only our own pixels when empty, so the blueprint child still shows.
	self_modulate.a = 1.0 if stage > EMPTY_STAGE else 0.0
	if stage > EMPTY_STAGE:
		frame = _stage_frame(stage)
	_update_blueprint(stage)

func _stage_frame(stage : int) -> int:
	return last_stage() - stage if reverse_frames else stage

## Blue ghost of the next frame, drawn behind the sprite so it only fills in
## the parts that aren't built yet. Hidden once the building is finished.
func _update_blueprint(stage : int) -> void:
	var next := stage + 1
	if next > last_stage():
		if _blueprint != null:
			_blueprint.visible = false
		return
	if _blueprint == null:
		_blueprint = Sprite2D.new()
		_blueprint.show_behind_parent = true
		_blueprint.material = ShaderMaterial.new()
		_blueprint.material.shader = BLUEPRINT_SHADER
		_blueprint.material.set_shader_parameter("blocked", not _missing.is_empty())
		add_child(_blueprint)
	_blueprint.texture = texture
	_blueprint.hframes = hframes
	_blueprint.vframes = vframes
	_blueprint.centered = centered
	_blueprint.offset = _base_offset
	_blueprint.flip_h = flip_h
	_blueprint.flip_v = flip_v
	_blueprint.region_enabled = region_enabled
	_blueprint.region_rect = region_rect
	_blueprint.frame = _stage_frame(next)
	_blueprint.visible = true

func display_name() -> String:
	return scene_file_path.get_file().get_basename().trim_suffix("_build").capitalize()

func total_cost() -> int:
	var total := 0
	for kind in costs:
		total += costs[kind]
	return total

## What the next frame still needs beyond what's delivered or on the way. Empty = not stuck.
func missing() -> Dictionary[String, int]:
	return _missing.duplicate()

func can_afford() -> bool:
	return _has_resources(min_to_start)

func jobs_needed() -> int:
	var total := 0
	for kind in min_to_start:
		total += min_to_start[kind]
	return mini(total, JobSystem.capacity())

func can_start() -> bool:
	return can_afford() and JobSystem.has_room(jobs_needed())

func start_construction() -> void:
	_built = EMPTY_STAGE
	_constructing = true
	_banked.clear()
	_incoming.clear()
	Inventory.changed.connect(_request_hauls)
	JobSystem.changed.connect(_post_jobs)
	_advance()
	_request_hauls()

func deliver(kind : String) -> void:
	_incoming[kind] = _incoming.get(kind, 0) - 1
	_banked[kind] = _banked.get(kind, 0) + 1
	_advance()
	_refresh_missing()

func complete() -> void:
	_set_stage(last_stage())
	area.input_pickable = true
	spawn_effect(BUILD_EFFECT, 1)
	JobSystem.worker_idle.connect(_on_worker_idle)
	completed.emit()

func has_idle_work(_worker : Meeple) -> bool:
	return false

func _make_idle_job(_worker : Meeple) -> IdleJob:
	return null

func claim_idle_job(worker : Meeple) -> IdleJob:
	if _idle_job != null:
		return null
	_idle_job = _make_idle_job(worker)
	if _idle_job != null:
		_idle_job.site = self
	return _idle_job

func idle_job_ended() -> void:
	_idle_job = null

func _on_worker_idle(worker : Meeple, offers : Array) -> void:
	if _idle_job == null and has_idle_work(worker):
		offers.append(self)

func _advance() -> void:
	while _built < last_stage():
		var cost := _frame_cost(_built + 1)
		if not _covers(_banked, cost):
			break
		for kind in cost:
			_banked[kind] -= cost[kind]
		_built += 1
	if _built >= last_stage():
		_finish_construction()
	else:
		_set_stage(_built)

func _finish_construction() -> void:
	_constructing = false
	_set_missing({})
	Inventory.changed.disconnect(_request_hauls)
	if JobSystem.changed.is_connected(_post_jobs):
		JobSystem.changed.disconnect(_post_jobs)
	complete()

func _request_hauls() -> void:
	if not _constructing or _requesting:
		return
	_requesting = true
	var remaining := _remaining_costs()
	for kind in remaining:
		var want : int = remaining[kind] - _banked.get(kind, 0) - _incoming.get(kind, 0)
		for i in range(mini(want, Inventory.available(kind))):
			Inventory.reserve(kind, 1)
			_incoming[kind] = _incoming.get(kind, 0) + 1
			_unposted.append(HaulJob.new(self, kind))
	_post_jobs()
	_refresh_missing()
	_requesting = false

func _post_jobs() -> void:
	while not _unposted.is_empty() and JobSystem.has_room():
		JobSystem.add(_unposted.pop_front())

func _refresh_missing() -> void:
	if not _constructing:
		return
	var next := _frame_cost(_built + 1)
	var now : Dictionary[String, int] = {}
	for kind in next:
		var short : int = next[kind] - _banked.get(kind, 0) - _incoming.get(kind, 0)
		if short > 0:
			now[kind] = short
	if not now.is_empty() and _missing.is_empty():
		print("%s needs %s to keep building" % [display_name(), _missing_text(now)])
	_set_missing(now)

func _set_missing(now : Dictionary[String, int]) -> void:
	if now == _missing:
		return
	_missing = now
	if _blueprint != null:
		_blueprint.material.set_shader_parameter("blocked", not _missing.is_empty())
	missing_changed.emit()

func _frame_cost(stage : int) -> Dictionary[String, int]:
	if stage < 0 or stage >= frames.size() or frames[stage] == null:
		return {}
	return frames[stage].costs

func _remaining_costs() -> Dictionary[String, int]:
	var sum : Dictionary[String, int] = {}
	for stage in range(_built + 1, last_stage() + 1):
		var cost := _frame_cost(stage)
		for kind in cost:
			sum[kind] = sum.get(kind, 0) + cost[kind]
	return sum

func _covers(have : Dictionary, need : Dictionary[String, int]) -> bool:
	for kind in need:
		if have.get(kind, 0) < need[kind]:
			return false
	return true

func _has_resources(need : Dictionary[String, int]) -> bool:
	for kind in need:
		if Inventory.available(kind) < need[kind]:
			return false
	return true

func _missing_text(need : Dictionary[String, int]) -> String:
	var parts := []
	for kind in need:
		parts.append("%d more %s" % [need[kind], kind])
	return " and ".join(parts)

func _sum_frame_costs() -> Dictionary[String, int]:
	var sum : Dictionary[String, int] = {}
	for stage in range(last_stage() + 1):
		var cost := _frame_cost(stage)
		for kind in cost:
			sum[kind] = sum.get(kind, 0) + cost[kind]
	return sum
