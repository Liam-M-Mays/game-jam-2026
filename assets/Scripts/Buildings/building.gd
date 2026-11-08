extends GridObject
class_name Building

signal completed

const BUILD_EFFECT := preload("res://assets/Scenes/Effects/cloud.tscn")
const EMPTY_STAGE := -1
const BLUEPRINT_SHADER := preload("res://assets/Shaders/blueprint.gdshader")
const PREVIEW_OPACITY := 0.5

## Tick on if the sheet runs finished -> empty (left to right) instead of empty -> finished.
@export var reverse_frames := false
@export var build_frames := 0
## Each phase is paid and hauled in order. No phases = the building is free.
@export var phases : Array[BuildPhase] = []

## Total cost of all phases (read-only; edit the phases instead).
var costs : Dictionary[String, int]:
	get:
		return _sum_phase_costs()

var _steps : Array[BuildPhase] = []
var _phase := 0
var _phase_delivered := 0
var _unposted : Array[HaulJob] = []
var _idle_job : IdleJob = null
var _blueprint : Sprite2D = null

func _ready() -> void:
	super()
	area.input_pickable = false
	if not phases.is_empty() and total_cost() != last_stage() + 1:
		push_warning("%s costs %d but has %d build frames" % [display_name(), total_cost(), last_stage() + 1])

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

func can_afford() -> bool:
	return _has_resources(_phase_list()[0].costs)

func jobs_needed() -> int:
	return mini(_phase_list()[0].total(), JobSystem.capacity())

func can_start() -> bool:
	return can_afford() and JobSystem.has_room(jobs_needed())

func start_construction() -> void:
	_set_stage(EMPTY_STAGE)
	_steps = _phase_list()
	_start_phase(0)

func deliver() -> void:
	var phase := _steps[_phase]
	_phase_delivered += 1
	_set_stage(_delivery_stage(phase))
	if _phase_delivered < phase.total():
		return
	if _phase + 1 == _steps.size():
		spawn_effect(BUILD_EFFECT, 1)
	_start_phase(_phase + 1)

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

func _start_phase(index : int) -> void:
	_phase = index
	_phase_delivered = 0
	if _phase >= _steps.size():
		complete()
		return
	var phase := _steps[_phase]
	if phase.total() == 0:
		_set_stage(_phase_end_stage(phase))
		_start_phase(index + 1)
		return
	if not _has_resources(phase.costs):
		print("%s needs %s to keep building" % [display_name(), _missing_text(phase.costs)])
		Inventory.changed.connect(_resume_phase)
		return
	_begin_phase(phase)

func _resume_phase() -> void:
	var phase := _steps[_phase]
	if not _has_resources(phase.costs):
		return
	Inventory.changed.disconnect(_resume_phase)
	_begin_phase(phase)

func _begin_phase(phase : BuildPhase) -> void:
	for kind in phase.costs:
		Inventory.reserve(kind, phase.costs[kind])
		for i in range(phase.costs[kind]):
			_unposted.append(HaulJob.new(self, kind))
	_post_jobs()
	if not _unposted.is_empty() and not JobSystem.changed.is_connected(_post_jobs):
		JobSystem.changed.connect(_post_jobs)

func _post_jobs() -> void:
	while not _unposted.is_empty() and JobSystem.has_room():
		JobSystem.add(_unposted.pop_front())
	if _unposted.is_empty() and JobSystem.changed.is_connected(_post_jobs):
		JobSystem.changed.disconnect(_post_jobs)

func _delivery_stage(phase : BuildPhase) -> int:
	var from := _phase_start_stage()
	var to := _phase_end_stage(phase)
	if to <= from:
		return from
	if phase.total() == 1:
		return to
	var t := float(_phase_delivered - 1) / (phase.total() - 1)
	return from + 1 + roundi((to - from - 1) * t)

func _phase_start_stage() -> int:
	return EMPTY_STAGE if _phase == 0 else _phase_end_stage(_steps[_phase - 1])

func _phase_end_stage(phase : BuildPhase) -> int:
	return last_stage() if phase.frame < 0 else mini(phase.frame, last_stage())

func _has_resources(need : Dictionary[String, int]) -> bool:
	for kind in need:
		if Inventory.available(kind) < need[kind]:
			return false
	return true

func _missing_text(need : Dictionary[String, int]) -> String:
	var parts := []
	for kind in need:
		var missing := need[kind] - Inventory.available(kind)
		if missing > 0:
			parts.append("%d more %s" % [missing, kind])
	return " and ".join(parts)

func _phase_list() -> Array[BuildPhase]:
	var list : Array[BuildPhase] = []
	for phase in phases:
		if phase != null:
			list.append(phase)
	if list.is_empty():
		list.append(BuildPhase.new())
	return list

func _sum_phase_costs() -> Dictionary[String, int]:
	var sum : Dictionary[String, int] = {}
	for phase in phases:
		if phase == null:
			continue
		for kind in phase.costs:
			sum[kind] = sum.get(kind, 0) + phase.costs[kind]
	return sum
