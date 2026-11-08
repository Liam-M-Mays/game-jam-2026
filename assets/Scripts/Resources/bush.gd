extends Harvestable
class_name Bush

@export var frames : SpriteFrames
@export var animation := &"default"
@export var food_per_harvest := 2
@export var regrow_time := 15.0
@export var empties_to_destroy := 3

var _times_emptied := 0
var _stage := 0
var _regrow_timer := 0.0
var _clearing := false

func _ready() -> void:
	super()
	_set_stage(0)
	Inventory.changed.connect(_cancel_picking_if_full)

func _cancel_picking_if_full() -> void:
	if _job is HarvestJob and not _clearing and Inventory.food_full():
		JobSystem.cancel(_job)
		_set_job(null)

func _process(delta : float) -> void:
	if _stage == 0 or _clearing:
		return
	_regrow_timer += delta
	if _regrow_timer >= regrow_time:
		_regrow_timer = 0.0
		_set_stage(_stage - 1)

func _on_clicked() -> void:
	if _job == null and _stage >= _last_stage():
		_clearing = true
	if _job == null and not _clearing and Inventory.food_full():
		reject()
		print("Food is full. Build a silo to store more")
		return
	super()
	if _job == null:
		_clearing = false

func can_harvest() -> bool:
	if _clearing:
		return super()
	return _stage < _last_stage() and not Inventory.food_full()

func _hit() -> bool:
	if _clearing:
		return super()
	if Inventory.food_full():
		return true
	_set_stage(_stage + 1)
	_regrow_timer = 0.0
	Inventory.add("food", food_per_harvest)
	if _stage >= _last_stage():
		_times_emptied += 1
		if _times_emptied >= empties_to_destroy:
			_shatter()
			return true
	_react()
	return not can_harvest()

func _last_stage() -> int:
	return frames.get_frame_count(animation) - 1

func _set_stage(stage : int) -> void:
	_stage = clampi(stage, 0, _last_stage())
	texture = frames.get_frame_texture(animation, _stage)
