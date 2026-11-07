extends resource
class_name Bush

## Berry bush: each hit from a meeple advances one frame and adds food straight
## to the inventory (no ground drops). Once bare it can't be harvested, and it
## regrows one frame at a time.

## Frames from full (first) to bare (last).
@export var frames : SpriteFrames
@export var animation := &"default"
@export var food_per_harvest := 2
## Seconds to regrow one frame.
@export var regrow_time := 15.0

var _stage := 0
var _regrow_timer := 0.0

func _ready() -> void:
	super()
	_set_stage(0)

func _last_stage() -> int:
	return frames.get_frame_count(animation) - 1

func _set_stage(stage : int) -> void:
	_stage = clampi(stage, 0, _last_stage())
	texture = frames.get_frame_texture(animation, _stage)
	_refresh_region()

func _can_mine() -> bool:
	return _stage < _last_stage()

## Called by MineJob on each hit. Returns true when the job is finished.
func mine() -> bool:
	if not _can_mine():
		return _finish_harvest()
	_squash()
	_flash()
	_wobble()
	_set_stage(_stage + 1)
	_regrow_timer = 0.0
	Inventory.add_food(food_per_harvest)
	if not _can_mine():
		return _finish_harvest()
	return false

## Bush stays in the world, so clear the selection when the meeple is done.
func _finish_harvest() -> bool:
	_mine_job = null
	_set_outline(false)
	return true

func _process(delta : float) -> void:
	if _stage == 0:
		return
	_regrow_timer += delta
	if _regrow_timer >= regrow_time:
		_regrow_timer = 0.0
		_set_stage(_stage - 1)
