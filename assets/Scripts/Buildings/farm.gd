extends Building
class_name Farm

@export var grow_time := 12.0
@export var food_per_harvest := 1
@export var harvest_time := 1.5

var barn : Barn = null

var _growing := false
var _growth := 0
var _grow_timer := 0.0

func grow_stages() -> int:
	return hframes - (last_stage() + 1)

func is_ripe() -> bool:
	return _growing and _growth >= grow_stages()

func restricts_placement() -> bool:
	return true

func placement_area(_grid : Grid) -> Array[Cell]:
	var cells : Array[Cell] = []
	for b in _barns_with_room():
		for cell in b.farm_area():
			if not cells.has(cell):
				cells.append(cell)
	return cells

func can_place_at(_grid : Grid, cells : Array[Cell]) -> bool:
	return _barn_for(cells) != null

func placement_hint() -> String:
	if _barns_with_room().is_empty():
		return "Farm plots need a barn with a free slot. Build another barn"
	return "Farm plots have to go in the highlighted area around a barn"

func start_construction() -> void:
	barn = _barn_for(cells)
	if barn != null:
		barn.add_farm(self)
	super()

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
	if not is_ripe():
		return
	Inventory.add("food", food_per_harvest)
	flash()
	_set_growth(0)

func has_idle_work(_worker : Meeple) -> bool:
	return is_ripe()

func _make_idle_job(_worker : Meeple) -> IdleJob:
	return FarmJob.new() if is_ripe() else null

func _set_growth(stage : int) -> void:
	_growth = clampi(stage, 0, grow_stages())
	_grow_timer = 0.0
	frame = last_stage() + _growth

func _barns_with_room() -> Array[Barn]:
	var list : Array[Barn] = []
	for node in get_tree().get_nodes_in_group(Barn.GROUP):
		if node.has_farm_room():
			list.append(node)
	return list

func _barn_for(plot : Array[Cell]) -> Barn:
	for b in _barns_with_room():
		if b.in_farm_range(plot):
			return b
	return null
