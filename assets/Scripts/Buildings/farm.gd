extends BarnPlot
class_name Farm

@export var grow_time := 12.0
@export var food_per_harvest := 1
@export var harvest_time := 1.5

var _growing := false
var _growth := 0
var _grow_timer := 0.0

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

func _process(delta : float) -> void:
	if not _growing or is_ripe():
		return
	_grow_timer += delta
	if _grow_timer >= grow_time:
		_grow_timer = 0.0
		_set_growth(_growth + 1)

func harvest_crop() -> void:
	if not can_harvest_now():
		return
	Inventory.add("food", food_per_harvest)
	VillageAudio.play(&"grass", global_position)
	flash()
	_set_growth(0)

func _set_growth(stage : int) -> void:
	_growth = clampi(stage, 0, grow_stages())
	_grow_timer = 0.0
	_show_frame(last_stage() + _growth)
