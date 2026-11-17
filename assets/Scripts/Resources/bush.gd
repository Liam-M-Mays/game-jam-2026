extends Harvestable
class_name Bush

@export var frames : SpriteFrames
@export var animation := &"default"
@export var food_per_harvest := 2
@export var regrow_time := 15.0
@export var empties_to_destroy := 3

# Its stage, regrow timer and empty count live in `standing`, so they stay while its row draws it.
var _clearing := false

func _ready() -> void:
	super()
	_set_stage(standing.stage)
	Inventory.changed.connect(_cancel_picking_if_full)

func _cancel_picking_if_full() -> void:
	if _job is HarvestJob and not _clearing and Inventory.food_full():
		JobSystem.cancel(_job)
		_set_job(null)

func _process(delta : float) -> void:
	if not _clearing and regrow(standing, delta):
		_set_stage(standing.stage)

## Moves `item` towards growing one stage back. The grid calls this on the template while the row
## draws the bush. True when it grew back a stage.
func regrow(item : Standing, delta : float) -> bool:
	if item.stage == 0:
		return false
	item.regrow_timer += delta
	if item.regrow_timer < regrow_time:
		return false
	item.regrow_timer = 0.0
	item.stage -= 1
	return true

func texture_for(item : Standing) -> Texture2D:
	return frames.get_frame_texture(animation, item.stage)

func _on_clicked() -> void:
	if _job == null and standing.stage >= _last_stage():
		_clearing = true
	if _job == null and not _clearing and Inventory.food_full():
		reject()
		GameState.warn("Food is full. Build a silo to store more")
		return
	super()
	if _job == null:
		_clearing = false

func cancel_job() -> void:
	super()
	_clearing = false

## A bush in the way of a building is cut down, not picked.
func mark_for_clearing() -> void:
	if _job == null:
		_clearing = true
	super()

func can_harvest() -> bool:
	if _clearing:
		return super()
	return standing.stage < _last_stage() and not Inventory.food_full()

func _hit() -> bool:
	if _clearing:
		return super()
	if Inventory.food_full():
		return true
	_set_stage(standing.stage + 1)
	standing.regrow_timer = 0.0
	Inventory.add("food", food_per_harvest)
	if standing.stage >= _last_stage():
		standing.emptied += 1
		if standing.emptied >= empties_to_destroy:
			_shatter()
			return true
	_react()
	return not can_harvest()

func _last_stage() -> int:
	return frames.get_frame_count(animation) - 1

func _set_stage(stage : int) -> void:
	standing.stage = clampi(stage, 0, _last_stage())
	texture = texture_for(standing)
