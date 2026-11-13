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
		return "%s needs a finished barn with a free slot. Finish or build a barn, or build a windmill" % display_name()
	return "%s has to go in the highlighted area around a barn" % display_name()

func start_construction() -> void:
	barn = _barn_for(cells)
	if barn != null:
		barn.add_plot(self)
	super()

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
