extends BarnPlot
class_name Farm

@export var grow_time := 12.0
@export var food_per_harvest := 1
@export var harvest_time := 1.5

var _growing := false
var _growth := 0
var _grow_timer := 0.0
var _collect_job : CollectCropJob = null

func grow_stages() -> int:
	return hframes - (last_stage() + 1)

func is_ripe() -> bool:
	return _growing and _growth >= grow_stages()

func can_harvest_now() -> bool:
	return is_ripe() and not Inventory.food_full()

func complete() -> void:
	super()
	_growing = true
	_set_growth(0)
	Inventory.changed.connect(_cancel_collect_if_full)

func _on_clicked() -> void:
	if _collect_job != null:
		_cancel_collect()
	elif is_ripe():
		_queue_collect()

func _queue_collect() -> void:
	var job := CollectCropJob.new(self)
	if not can_harvest_now():
		reject()
		return
	JobSystem.add(job)
	_set_collect_job(job)

func _cancel_collect() -> void:
	JobSystem.cancel(_collect_job)
	_set_collect_job(null)

func _cancel_collect_if_full() -> void:
	if _collect_job != null and Inventory.food_full():
		_cancel_collect()

func _set_collect_job(job : CollectCropJob) -> void:
	_collect_job = job
	set_selected(job != null)

func _process(delta : float) -> void:
	if not _growing or is_ripe():
		return
	_grow_timer += delta
	if _grow_timer >= grow_time:
		_grow_timer = 0.0
		_set_growth(_growth + 1)

func harvest_crop() -> void:
	_set_collect_job(null)
	if not can_harvest_now():
		return
	Inventory.add("food", food_per_harvest)
	VillageAudio.play(&"grass", global_position)
	flash()
	_set_growth(0)

## True when the barn's worker should harvest it: it is ripe and the player did not send a builder.
func needs_harvest() -> bool:
	return can_harvest_now() and _collect_job == null

func _set_growth(stage : int) -> void:
	_growth = clampi(stage, 0, grow_stages())
	_grow_timer = 0.0
	_show_frame(last_stage() + _growth)
