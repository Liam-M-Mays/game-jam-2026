extends Harvestable
class_name Bush

@export var frames : SpriteFrames
@export var animation := &"default"
@export var food_per_harvest := 2
@export var regrow_time := 15.0

var _stage := 0
var _regrow_timer := 0.0
var _clearing := false

func _ready() -> void:
	super()
	_set_stage(0)

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
	super()
	if _job == null:
		_clearing = false

func can_harvest() -> bool:
	if _clearing:
		return super()
	return _stage < _last_stage()

func _hit() -> bool:
	if _clearing:
		return super()
	_react()
	_set_stage(_stage + 1)
	_regrow_timer = 0.0
	Inventory.add("food", food_per_harvest)
	return not can_harvest()

func _last_stage() -> int:
	return frames.get_frame_count(animation) - 1

func _set_stage(stage : int) -> void:
	_stage = clampi(stage, 0, _last_stage())
	texture = frames.get_frame_texture(animation, _stage)
