extends GridObject
class_name Building

signal completed

const BUILD_EFFECT := preload("res://assets/Scenes/Effects/cloud.tscn")
## Stage shown right after placing: nothing drawn until the first delivery.
const EMPTY_STAGE := -1

## Total cost. When phases are set this is filled in from them automatically.
@export var costs : Dictionary[String, int] = {}
## Tick on if the sheet runs finished -> empty (left to right) instead of empty -> finished.
@export var reverse_frames := false
## How many frames at the start of the sheet are construction. 0 = the whole sheet.
## Frames after these belong to the finished building (e.g. storage fill levels).
@export var build_frames := 0
## Build steps in order. Each phase's resources are hauled before the next phase
## starts, and the sprite climbs to that phase's frame as they arrive.
## Only the first phase has to be affordable to place the building; later phases
## wait until their resources exist.
## Empty = one phase that uses costs and climbs to the finished frame.
@export var phases : Array[BuildPhase] = []:
	set(value):
		phases = value
		if not phases.is_empty():
			costs = _sum_phase_costs()

var _steps : Array[BuildPhase] = []
var _phase := 0
var _phase_delivered := 0
var _unposted : Array[HaulJob] = []

func _ready() -> void:
	super()
	area.input_pickable = false

func show_as_preview() -> void:
	_set_stage(last_stage())

## Stage of the finished building.
func last_stage() -> int:
	return (build_frames if build_frames > 0 else hframes) - 1

## EMPTY_STAGE = nothing drawn, 0 = first sheet frame, last_stage() = finished,
## regardless of sheet direction.
func _set_stage(stage : int) -> void:
	visible = stage > EMPTY_STAGE
	if not visible:
		return
	stage = mini(stage, last_stage())
	frame = last_stage() - stage if reverse_frames else stage

func display_name() -> String:
	return scene_file_path.get_file().get_basename().trim_suffix("_build").capitalize()

func total_cost() -> int:
	var total := 0
	for kind in costs:
		total += costs[kind]
	return total

## Only the first phase has to be affordable to start building.
func can_afford() -> bool:
	return _has_resources(_phase_list()[0].costs)

## Queue slots needed to start: the first phase, capped at the queue's size so an
## oversized phase is still placeable (its extra jobs trickle in).
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
	if _phase + 1 < _steps.size():
		spawn_effect(BUILD_EFFECT, 1)
	_start_phase(_phase + 1)

func complete() -> void:
	_set_stage(last_stage())
	area.input_pickable = true
	spawn_effect(BUILD_EFFECT, 1)
	completed.emit()

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

## Called on every inventory change while a phase is waiting for resources.
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

## Posts as many waiting haul jobs as the queue has room for.
func _post_jobs() -> void:
	while not _unposted.is_empty() and JobSystem.has_room():
		JobSystem.add(_unposted.pop_front())
	if _unposted.is_empty() and JobSystem.changed.is_connected(_post_jobs):
		JobSystem.changed.disconnect(_post_jobs)

## First delivery of a phase shows the next frame, the last one lands exactly on
## the phase's frame, and the ones between are spread evenly.
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
		var only := BuildPhase.new()
		only.costs = costs
		list.append(only)
	return list

func _sum_phase_costs() -> Dictionary[String, int]:
	var sum : Dictionary[String, int] = {}
	for phase in phases:
		if phase == null:
			continue
		for kind in phase.costs:
			sum[kind] = sum.get(kind, 0) + phase.costs[kind]
	return sum
