extends Building
class_name BarnPlot

var barn : Barn = null

func restricts_placement() -> bool:
	return true

func placement_area(_grid : Grid) -> Array[Cell]:
	var area : Array[Cell] = []
	for b in _barns_with_room():
		for cell in b.plot_area():
			if not area.has(cell):
				area.append(cell)
	return area

func can_place_at(_grid : Grid, plot : Array[Cell]) -> bool:
	return _barn_for(plot) != null

func placement_hint() -> String:
	if _barns_with_room().is_empty():
		return "%s needs a barn with a free slot. Build a barn or a windmill" % display_name()
	return "%s has to go in the highlighted area around a barn" % display_name()

func start_construction() -> void:
	barn = _barn_for(cells)
	if barn != null:
		barn.add_plot(self)
	super()

func remove_building() -> void:
	if barn != null:
		barn.plots.erase(self)
	super()

## Keeps placing the same kind while a barn has room for it.
func build_after(scene : PackedScene) -> PackedScene:
	return scene if not placement_area(grid).is_empty() else null

## The slots left in this plot's barn, or while placing, in the barn nearest the cursor.
func note() -> String:
	if barn != null:
		return barn.note()
	var mouse := get_global_mouse_position()
	var near : Barn = null
	for b : Barn in get_tree().get_nodes_in_group(Barn.GROUP):
		if near == null or b.global_position.distance_squared_to(mouse) < near.global_position.distance_squared_to(mouse):
			near = b
	return near.note() if near != null else ""

func can_move() -> bool:
	return false

func worker_building() -> Building:
	return barn.worker_building() if barn != null else null

func _barns_with_room() -> Array[Barn]:
	var list : Array[Barn] = []
	var tree := Engine.get_main_loop() as SceneTree
	for node in tree.get_nodes_in_group(Barn.GROUP):
		if node.has_room_for(self):
			list.append(node)
	return list

func _barn_for(plot : Array[Cell]) -> Barn:
	for b in _barns_with_room():
		if b.in_plot_range(plot):
			return b
	return null
