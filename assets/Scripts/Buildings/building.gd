extends GridObject
class_name Building

signal completed
signal missing_changed
## Its workers changed: one joined, left or died. The open panel listens, to outline the right meeples.
signal workers_changed

const BUILD_EFFECT := preload("res://assets/Scenes/Effects/cloud.tscn")
const EMPTY_STAGE := -1
const BLUEPRINT_SHADER := preload("res://assets/Shaders/blueprint.gdshader")
const PREVIEW_OPACITY := 0.5
const COMPLETED_GROUP := &"completed_buildings"
const CONSTRUCTION_GROUP := &"construction_sites"
const POP_RISE := 0.05
const POP_FALL := 0.13
const PAUSED_OUTLINE := Color(1.0, 0.85, 0.1)
## How often a building waiting for its land looks whether the land is clear, in seconds.
const LAND_CHECK_TIME := 0.25
## True: a finished building fills all its worker slots by itself, with the nearest free builders.
## False: it starts with no workers, and the player adds them with the arrows in its panel.
const STARTS_FULL := true

@export var pop_amount := 0.05
@export var reverse_frames := false
@export var build_frames := 0
@export var frames : Array[BuildFrame] = []
@export var min_to_start : Dictionary[String, int] = {}
@export var required_town_hall_level := 1
@export var show_blueprint := true
@export var icon_texture : Texture2D
@export_multiline var description := ""
## How many meeples work here once it is finished. Set in each building's scene.
@export var worker_slots := 0

var costs : Dictionary[String, int]:
	get:
		return _sum_frame_costs()

var _built := EMPTY_STAGE
var _constructing := false
var _paused := false
var _missing : Dictionary[String, int] = {}
var _requesting := false
var _banked : Dictionary[String, int] = {}
var _incoming : Dictionary[String, int] = {}
var workers : Array[Meeple] = []
## How many workers the player set with the panel's arrows. A slot with nobody in it waits for a free builder.
var wanted_workers := 0
var _blueprint : Sprite2D = null
## Checks the land while the building waits for trees, rocks or bushes on its cells to be cleared.
## Null when it is not waiting.
var _land_timer : Timer = null
## When the player placed it, on JobSystem's clock. Its deliveries count their age from here.
var ordered_at := 0.0

func _ready() -> void:
	super()
	area.input_pickable = false
	if not frames.is_empty() and frames.size() != last_stage() + 1:
		push_warning("%s has %d frame costs but %d build frames" % [display_name(), frames.size(), last_stage() + 1])

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
	self_modulate.a = 1.0 if stage > EMPTY_STAGE else 0.0
	frame = _stage_frame(maxi(stage, 0))
	_update_blueprint(stage)

func _stage_frame(stage : int) -> int:
	return last_stage() - stage if reverse_frames else stage

func _update_blueprint(stage : int) -> void:
	var next := stage + 1
	if next > last_stage() or not show_blueprint:
		_outline_also_around(frame)
		if _blueprint != null:
			_blueprint.visible = false
		return
	_outline_also_around(_stage_frame(next))
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

func missing() -> Dictionary[String, int]:
	return _missing.duplicate()

func next_stage_needs() -> Dictionary[String, int]:
	var needs : Dictionary[String, int] = {}
	if not _constructing:
		return needs
	var next := _frame_cost(_built + 1)
	for kind in next:
		var short : int = next[kind] - _banked.get(kind, 0)
		if short > 0:
			needs[kind] = short
	return needs

func is_under_construction() -> bool:
	return _constructing

func is_paused() -> bool:
	return _paused

func toggle_paused() -> void:
	if not _constructing:
		return
	_paused = not _paused
	set_selected(_paused, PAUSED_OUTLINE)
	if _paused:
		JobSystem.recall_hauls(self)
		_drop_queued_hauls()
		_set_missing({})
	else:
		_request_hauls()

func icon() -> Texture2D:
	if icon_texture != null:
		return _cropped_icon(icon_texture, Rect2(Vector2.ZERO, icon_texture.get_size()))
	var sheet := region_rect if region_enabled else Rect2(Vector2.ZERO, texture.get_size())
	var size := sheet.size / Vector2(hframes, vframes)
	var index := _icon_frame()
	var cell := Vector2(index % hframes, floori(float(index) / hframes))
	return _cropped_icon(texture, Rect2(sheet.position + cell * size, size))

func _icon_frame() -> int:
	return _stage_frame(last_stage())

func _cropped_icon(source : Texture2D, region : Rect2) -> Texture2D:
	var image := source.get_image()
	if image != null and not image.is_compressed():
		var used := image.get_region(Rect2i(region)).get_used_rect()
		if used.has_area():
			region = Rect2(region.position + Vector2(used.position), Vector2(used.size))
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas

## Land a barn keeps for its farms and silos takes nothing else. A building being moved may go back onto its own cells.
func can_place_at(_grid : Grid, at_cells : Array[Cell]) -> bool:
	return at_cells.all(func(c : Cell): return c.kept_for == null or c.kept_for == self)

func restricts_placement() -> bool:
	return false

func placement_area(_grid : Grid) -> Array[Cell]:
	return []

func placement_hint() -> String:
	return "That land is kept for a barn's farms and silos"

## Cells to light around the cursor while this is placed at `anchor`. A barn shows its plot area.
func area_at(_grid : Grid, _anchor : Cell) -> Array[Cell]:
	return []

## What to place next after this was placed from `scene`, or null to end building.
func build_after(_scene : PackedScene) -> PackedScene:
	return null

## A line under the name in the building's panel, and next to the cursor while placing.
func note() -> String:
	return ""

func can_afford() -> bool:
	return _has_resources(min_to_start)

## True when it may be placed over trees, rocks and bushes, which meeples then clear. Barns, farms and silos do.
func clears_land() -> bool:
	return false

## Placing puts the building down on `at_cells` and starts building it. Trees, rocks or bushes on
## those cells are marked to be cleared first. Until they are gone, the building waits as a ghost:
## it keeps its cells and nothing is spent on it.
func put_down(at_grid : Grid, at_cells : Array[Cell]) -> void:
	if at_cells.all(func(c : Cell) -> bool: return c.occupant == null):
		at_grid.place(self, at_cells)
		start_construction()
		return
	grid = at_grid
	cells = at_cells
	position = at_cells[0].position
	for cell in at_cells:
		if cell.kept_for == null:
			cell.kept_for = self
	at_grid.add_child(self)
	show_as_preview()
	_land_timer = Timer.new()
	_land_timer.wait_time = LAND_CHECK_TIME
	_land_timer.timeout.connect(_check_land)
	add_child(_land_timer)
	_land_timer.start()
	_check_land()

func is_waiting_for_land() -> bool:
	return _land_timer != null

## Marks every tree, rock and bush on `at_cells` to be cleared.
func mark_land(at_grid : Grid, at_cells : Array[Cell]) -> void:
	for cell in at_cells:
		if cell.occupant is Standing:
			at_grid.wake(cell.occupant).mark_for_clearing()

## Starts building once its cells are clear. Until then it marks what still stands on them, again,
## in case a lumberjack or a bush picker let go of it.
func _check_land() -> void:
	if cells.any(func(c : Cell) -> bool: return c.occupant != null):
		mark_land(grid, cells)
		return
	_land_timer.queue_free()
	_land_timer = null
	for cell in cells:
		if cell.kept_for == self:
			cell.kept_for = null
	material = ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	grid.place(self, cells)
	start_construction()

## A clearing job on `cell` was cancelled. A building still waiting for that cell is not built.
func land_not_cleared(cell : Cell) -> void:
	if is_waiting_for_land() and cells.has(cell):
		cancel_waiting()

## Gives up waiting for the land: the building goes, and the clearing marks on its cells come off.
## Nothing was spent on it yet. `say` shows a toast that tells the player why.
func cancel_waiting(say := true) -> void:
	_land_timer.queue_free()
	_land_timer = null
	for cell in cells:
		if cell.kept_for == self:
			cell.kept_for = null
	for group in get_groups():
		if not String(group).begins_with("_"):
			remove_from_group(group)
	_unmark_land(cells)
	if say:
		GameState.warn("%s cancelled: its land is not being cleared" % display_name())
	queue_free()

## Takes the clearing marks off the trees, rocks and bushes on `at_cells`.
func _unmark_land(at_cells : Array[Cell]) -> void:
	for cell in at_cells:
		if cell.occupant is Standing:
			var node := (cell.occupant as Standing).node
			if node != null and node.is_marked():
				node.cancel_job()

func start_construction() -> void:
	ordered_at = JobSystem.now()
	_built = EMPTY_STAGE
	_constructing = true
	_banked.clear()
	_incoming.clear()
	area.input_pickable = true
	add_to_group(CONSTRUCTION_GROUP)
	Inventory.changed.connect(_request_hauls)
	_advance()
	_request_hauls()

func deliver(kind : String) -> void:
	_incoming[kind] = _incoming.get(kind, 0) - 1
	_banked[kind] = _banked.get(kind, 0) + 1
	VillageAudio.play(&"hammer", global_position)
	_pop()
	_advance()
	_request_hauls()
	_refresh_missing()

func complete() -> void:
	_set_stage(last_stage())
	area.input_pickable = true
	spawn_effect(BUILD_EFFECT, 1)
	add_to_group(COMPLETED_GROUP)
	for i in range(worker_slots if STARTS_FULL else 0):
		add_worker_slot()
	completed.emit()

func _on_clicked() -> void:
	if is_in_group(COMPLETED_GROUP):
		get_tree().call_group(WorkerPanel.GROUP, &"open", self)

## The building whose workers a click on this one sets, or null. A farm or a silo answers with its barn.
func worker_building() -> Building:
	return self if worker_slots > 0 and is_in_group(COMPLETED_GROUP) else null

## The panel's add arrow: one more slot, which the nearest free builder takes.
func add_worker_slot() -> void:
	if wanted_workers >= worker_slots:
		return
	wanted_workers += 1
	JobSystem.open_slot(self)

## The panel's remove arrow: drops a slot nobody took yet, or else sends a worker back to being a builder.
func remove_worker_slot() -> void:
	if wanted_workers <= 0:
		return
	wanted_workers -= 1
	if not JobSystem.close_slot(self) and not workers.is_empty():
		workers.pop_back().leave_workplace()
		workers_changed.emit()

## The next task for `worker`, one of this building's workers, or null when there is nothing to do.
func find_work(_worker : Meeple) -> Job:
	return null

## Makes `meeple` a worker of this building.
func add_worker(meeple : Meeple) -> void:
	workers.append(meeple)
	meeple.workplace = self
	workers_changed.emit()

## Frees the slot of a worker who died, so another meeple takes it.
func lose_worker(meeple : Meeple) -> void:
	workers.erase(meeple)
	JobSystem.open_slot(self)
	workers_changed.emit()

## False hides nothing but dims the panel's Remove button. The Town Hall answers false.
func can_remove() -> bool:
	return true

## What the panel asks before it removes the building.
func remove_question() -> String:
	return "Remove this %s?" % display_name()

## The panel's Remove button. What the building cost pops out as drops, its workers go back
## to being builders, and the jobs that bring it drops are cancelled.
func remove_building() -> void:
	if not can_remove():
		return
	if is_waiting_for_land():
		cancel_waiting(false)
		return
	var refund := _spent()
	if _constructing:
		JobSystem.recall_hauls(self)
		_drop_queued_hauls()
		Inventory.changed.disconnect(_request_hauls)
		_constructing = false
	while JobSystem.close_slot(self):
		pass
	for worker in workers:
		worker.leave_workplace()
	workers.clear()
	wanted_workers = 0
	# Out of every group now, so nothing finds it as a barn, a pile or a silo before it is freed.
	for group in get_groups():
		if not String(group).begins_with("_"):
			remove_from_group(group)
	Inventory.mark_changed()
	spawn_effect(BUILD_EFFECT, 1)
	grid.remove(self)
	_pop_out(refund)

## False dims the panel's Move button. A farm or a silo answers false: it moves with its barn.
func can_move() -> bool:
	return true

## Takes the building off its cells while the player picks a new spot. Its old cells stay kept for it,
## so no tree grows there and Escape can always put it back.
func lift() -> void:
	grid.lift(self)
	for cell in cells:
		if cell.kept_for == null:
			cell.kept_for = self
	modulate.a = PREVIEW_OPACITY

## Puts a lifted building down on `at_cells`, new ones or its old ones. Its workers stay, and a meeple
## walking to it with a drop or to work turns towards the new spot.
func land(at_cells : Array[Cell]) -> void:
	for cell in cells:
		if cell.kept_for == self:
			cell.kept_for = null
	grid.place(self, at_cells)
	modulate.a = 1.0
	for meeple in JobSystem.workers:
		if meeple.job != null and meeple.job.goes_to(self):
			meeple.move_to(global_position, cells)

## Pops `amounts` out of the middle of the building in all directions, the way a tree's drops come out.
func _pop_out(amounts : Dictionary[String, int]) -> Array[ResourceDrop]:
	var middle := Vector2.ZERO
	for cell in cells:
		middle += cell.position
	middle /= maxi(cells.size(), 1)
	var dropped : Array[ResourceDrop] = []
	for kind in amounts:
		for i in range(amounts[kind]):
			var drop := grid.add_drop(ResourceDrop.scene_of(kind), middle)
			drop.launch()
			dropped.append(drop)
	return dropped

## What the player put into it: its whole cost once it is finished, or else the stages built and the drops delivered.
func _spent() -> Dictionary[String, int]:
	if is_in_group(COMPLETED_GROUP):
		return costs
	var sum : Dictionary[String, int] = _banked.duplicate()
	for stage in range(_built + 1):
		var cost := _frame_cost(stage)
		for kind in cost:
			sum[kind] = sum.get(kind, 0) + cost[kind]
	return sum

func _pop() -> void:
	var tween := _tween(&"pop").set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _base_scale * (1.0 + pop_amount), POP_RISE)
	tween.tween_property(self, "scale", _base_scale, POP_FALL)

func _show_frame(index : int) -> void:
	if index == frame:
		return
	frame = index
	flash()

func _advance() -> void:
	var before := _built
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
	if _built != before:
		flash()

func _finish_construction() -> void:
	_constructing = false
	_paused = false
	set_selected(false)
	remove_from_group(CONSTRUCTION_GROUP)
	_set_missing({})
	Inventory.changed.disconnect(_request_hauls)
	complete()

func _request_hauls() -> void:
	if not _constructing or _paused or _requesting:
		return
	_requesting = true
	var next := _frame_cost(_built + 1)
	for kind in next:
		var want : int = next[kind] - _banked.get(kind, 0) - _incoming.get(kind, 0)
		for i in range(mini(want, Inventory.available(kind))):
			Inventory.reserve(kind, 1)
			_incoming[kind] = _incoming.get(kind, 0) + 1
			JobSystem.add(HaulJob.new(self, kind))
	_refresh_missing()
	_requesting = false

func _drop_queued_hauls() -> void:
	for job in JobSystem.take_pending_hauls(self):
		_incoming[job.kind] -= 1
		job.release_drop()

func _refresh_missing() -> void:
	if not _constructing or _paused:
		return
	var next := _frame_cost(_built + 1)
	var now : Dictionary[String, int] = {}
	for kind in next:
		var short : int = next[kind] - _banked.get(kind, 0) - _incoming.get(kind, 0)
		if short > 0:
			now[kind] = short
	if not now.is_empty() and _missing.is_empty():
		GameState.warn("%s needs %s to keep building" % [display_name(), _missing_text(now)])
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

func built_stage() -> int:
	return _built
