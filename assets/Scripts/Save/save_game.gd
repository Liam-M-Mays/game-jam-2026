extends Node
## Autoload `SaveGame`. Keeps one saved village in user://savegame.dat and puts it back on Continue.
##
## What is saved: the world's seed (the same seed makes the same cells and ground), every tree, rock
## and bush with its wear and the player's marks, every building with its stage, workers, pile stock,
## farm growth and Town Hall level, every meeple with its colour and workplace, the drops on the
## ground, the food stock, the game speed, the camera and the one-time tips already shown. A building
## being moved keeps both halves: the old one coming down with what is left in it, and the new site.
## Builders keep their hauls and store trips, with what they carry. Other jobs start again: a marked tree or a
## worker's task goes back to the nearest meeple, which is nearly always the one that was on it.
##
## When: going back to the main menu, quitting, and on the Auto-save timer from Settings.
## Game over deletes the save, and Start asks before replacing it.

signal saved

const PATH := "user://savegame.dat"
## Bump when the saved data changes shape. An older save is not loaded.
const VERSION := 1
const AUTO_SAVE_SECONDS := {"Every 5 min": 300.0, "Every 10 min": 600.0}

## Where the save goes. Tests point it somewhere else.
var path := PATH
var _pending := {}
var _restoring := false
var _grid : Grid = null
## True when the open world came from a save, so the HUD skips the opening tutorial.
var _continued := false
var _game_over := false
var _since_save := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Population.all_meeples_died.connect(_on_game_over)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


func _process(delta: float) -> void:
	if _grid == null or _game_over or get_tree().paused:
		return
	var every: float = AUTO_SAVE_SECONDS.get(Settings.get_value(&"auto_save"), 0.0)
	if every <= 0.0:
		return
	_since_save += delta / maxf(Engine.time_scale, 0.001)
	if _since_save >= every:
		save_now()


func has_save() -> bool:
	return FileAccess.file_exists(path) and not _read().is_empty()


func delete_save() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Loads the save and opens its level. False when there is no save it can read.
func continue_game() -> bool:
	var data := _read()
	if data.is_empty():
		return false
	GameState.new_game()
	Inventory.restore_stored(data.get("stored", {}))
	GameState.set_speed_index(data.get("speed", 0))
	GameState.restore_tips_shown(data.get("tips", []))
	_pending = data
	SceneFader.change_scene(data.get("level", ""))
	return true


## Saves the open world now. Does nothing with no world open or after game over.
func save_now() -> bool:
	if _grid == null or _game_over or not is_instance_valid(_grid):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the game: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_var(_gather(_grid))
	_since_save = 0.0
	saved.emit()
	return true


## Saves, then quits the game.
func save_and_quit() -> void:
	save_now()
	get_tree().quit()


func is_restoring() -> bool:
	return _restoring


func has_pending() -> bool:
	return not _pending.is_empty()


func pending_seed() -> int:
	return _pending.get("seed", 0)


## True when the open world was loaded from a save.
func is_continued() -> bool:
	return _continued


## The grid calls this once its world is made, new or loaded.
func world_opened(grid: Grid) -> void:
	_grid = grid
	_game_over = false
	_since_save = 0.0
	_continued = not _pending.is_empty()
	_pending = {}


func world_closed(grid: Grid) -> void:
	if _grid == grid:
		_grid = null


func _on_game_over() -> void:
	_game_over = true
	delete_save()


func _read() -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	if not data is Dictionary or data.get("version", 0) != VERSION or not ResourceLoader.exists(data.get("level", "")):
		return {}
	return data


# --- Saving -------------------------------------------------------------------------------------

func _gather(grid: Grid) -> Dictionary:
	var buildings := _saved_buildings(grid)
	var index_of := {}
	for i in buildings.size():
		index_of[buildings[i]] = i
	var data := {
		"version": VERSION,
		"level": _level_of(grid),
		"seed": grid.world_seed(),
		"stored": Inventory.stored(),
		"speed": GameState.speed_index(),
		"tips": GameState.tips_shown(),
		"standing": [],
		"buildings": [],
		"meeples": [],
		"drops": [],
	}
	var camera := grid.get_viewport().get_camera_2d()
	if camera != null:
		data["camera"] = {"position": camera.global_position, "zoom": camera.zoom}
	for item in grid.all_standing():
		if item.wobbles >= item.kind.template.wobbles_to_break:
			continue
		var entry := {
			"scene": item.kind.scene.resource_path,
			"at": grid.coords_of(item.cells[0]),
			"wobbles": item.wobbles,
			"stage": item.stage,
			"regrow": item.regrow_timer,
			"emptied": item.emptied,
		}
		if item.node != null and item.node.is_marked():
			entry["marked"] = true
			entry["clearing"] = item.node.is_clearing()
		data["standing"].append(entry)
	for building: Building in buildings:
		data["buildings"].append(_save_building(grid, building, index_of))
	# A drop in a meeple's hands is saved with its job, not on the ground where it was picked up.
	var carried := {}
	for meeple in JobSystem.workers:
		# Only when the job is saved: otherwise the drop stays in the save as a drop on the ground.
		if not meeple.carried_drops().is_empty() and not _save_job(meeple, index_of, {}).is_empty():
			for drop in meeple.carried_drops():
				carried[drop] = true
	var drop_index := {}
	for drop in Inventory.all_drops():
		if drop.is_in_world() and not carried.has(drop):
			drop_index[drop] = data["drops"].size()
			data["drops"].append({"kind": drop.kind, "at": drop.position})
	for meeple in JobSystem.workers:
		var entry := {
			"at": meeple.position,
			"color": meeple.body_color(),
			"workplace": index_of.get(meeple.workplace, -1),
		}
		var job := _save_job(meeple, index_of, drop_index)
		if not job.is_empty():
			entry["job"] = job
		data["meeples"].append(entry)
	return data


## What a save keeps of a builder's job: a haul or a store trip. Empty for anything else.
func _save_job(meeple: Meeple, index_of: Dictionary, drop_index: Dictionary) -> Dictionary:
	if meeple.workplace != null:
		return {}
	if meeple.job is HaulJob:
		return (meeple.job as HaulJob).saved(index_of, drop_index)
	if meeple.job is StoreJob:
		return (meeple.job as StoreJob).saved(index_of, drop_index)
	return {}


## The scene file of the level the grid is in: the open scene, or the scene the grid was saved in.
func _level_of(grid: Grid) -> String:
	var scene := grid.get_tree().current_scene
	if scene != null and scene.is_ancestor_of(grid) and not scene.scene_file_path.is_empty():
		return scene.scene_file_path
	return grid.owner.scene_file_path if grid.owner != null else ""


## Reads the save file, for Continue and for tests. Empty when there is none it can read.
func read_save() -> Dictionary:
	return _read()


## Loads `data` into the next world that opens, for tests that open the level themselves.
func set_pending(data: Dictionary) -> void:
	_pending = data


## What a save of `grid` would hold right now, for tests.
func gather(grid: Grid) -> Dictionary:
	return _gather(grid)


## The buildings that are on the grid for real: finished, being built, waiting for their land, or coming down
## for a move. Those coming down come first, so a moved site can find its old building when loading. Then barns,
## and farms and silos last, so a farm can join its barn.
func _saved_buildings(grid: Grid) -> Array[Building]:
	var coming: Array[Building] = []
	var barns: Array[Building] = []
	var others: Array[Building] = []
	var plots: Array[Building] = []
	for child in grid.get_children():
		var building := child as Building
		if building == null or building.is_queued_for_deletion() or building.cells.is_empty():
			continue
		if building.is_coming_down():
			coming.append(building)
			continue
		if not (building.is_in_group(Building.COMPLETED_GROUP) or building.is_under_construction() or building.is_waiting_for_land()):
			continue
		if building is Barn:
			barns.append(building)
		elif building is BarnPlot:
			plots.append(building)
		else:
			others.append(building)
	return coming + barns + others + plots


func _save_building(grid: Grid, building: Building, index_of: Dictionary) -> Dictionary:
	var cells := []
	for cell in building.cells:
		cells.append(grid.coords_of(cell))
	var entry := {"scene": building.scene_file_path, "cells": cells, "order": building.build_order}
	if index_of.has(building.moved_from()):
		entry["from"] = index_of[building.moved_from()]
	if building.was_moved():
		entry["moved"] = true
	if building.is_coming_down():
		entry["state"] = "coming_down"
		entry["left"] = building.left_state()
	elif building.is_waiting_for_land():
		entry["state"] = "waiting"
	elif building.is_under_construction():
		entry["state"] = "building"
		entry.merge(building.construction_state())
	else:
		entry["state"] = "done"
		entry["wanted_workers"] = building.wanted_workers
	if building is TownHall:
		entry["level"] = (building as TownHall).level()
	if building is Storage:
		entry["stock"] = (building as Storage).held()
	if building is Farm:
		entry["growth"] = (building as Farm).growth_state()
	return entry


# --- Loading ------------------------------------------------------------------------------------

## The grid calls this instead of making a new map, when a save is waiting to be loaded.
func restore_world(grid: Grid) -> void:
	var data := _pending
	_restoring = true
	for entry in data.get("standing", []):
		_restore_standing(grid, entry)
	var buildings: Array = []
	for entry in data.get("buildings", []):
		buildings.append(_restore_building(grid, entry, buildings))
	var meeples: Array = []
	for entry in data.get("meeples", []):
		var meeple := grid.spawn_meeple(entry.get("at", Vector2.ZERO))
		meeple.restore_body_color(entry.get("color", Color.WHITE))
		var index: int = entry.get("workplace", -1)
		var workplace: Building = buildings[index] if index >= 0 and index < buildings.size() else null
		if workplace != null and JobSystem.close_slot(workplace):
			workplace.add_worker(meeple)
		meeples.append(meeple)
	var drops: Array = []
	for entry in data.get("drops", []):
		var kind: String = entry.get("kind", "")
		drops.append(grid.add_drop(ResourceDrop.scene_of(kind), entry.get("at", Vector2.ZERO)) if ResourceDrop.SCENES.has(kind) else null)
	# Store trips first, so a pile counts the drops on their way to it before hauls claim from it.
	for type in ["store", "haul"]:
		for i in meeples.size():
			var job: Dictionary = data["meeples"][i].get("job", {})
			if job.get("type", "") == type:
				_restore_job(grid, meeples[i], job, buildings, drops)
	_restoring = false
	# The sites ask for stock now that everything is back, oldest first, so a newer one does not go first.
	var sites := grid.get_tree().get_nodes_in_group(Building.CONSTRUCTION_GROUP)
	sites.sort_custom(func(a: Building, b: Building) -> bool: return a.build_order < b.build_order)
	for site: Building in sites:
		site.request_hauls()
	Inventory.mark_changed()
	if data.has("camera"):
		_restore_camera.call_deferred(data["camera"])


func _restore_standing(grid: Grid, entry: Dictionary) -> void:
	var path: String = entry.get("scene", "")
	if not ResourceLoader.exists(path):
		return
	var item := grid.restore_standing(load(path), entry.get("at", Vector2i.ZERO))
	if item == null:
		return
	item.wobbles = entry.get("wobbles", 0)
	item.stage = entry.get("stage", 0)
	item.regrow_timer = entry.get("regrow", 0.0)
	item.emptied = entry.get("emptied", 0)
	if entry.get("marked", false):
		grid.wake(item).restore_mark(entry.get("clearing", true))


## `restored` holds the buildings put back so far, in save order, so a moved site finds its old building.
func _restore_building(grid: Grid, entry: Dictionary, restored: Array) -> Building:
	var path: String = entry.get("scene", "")
	if not ResourceLoader.exists(path):
		return null
	var cells: Array[Cell] = []
	for coords in entry.get("cells", []):
		var cell := grid.cell_at_coords(coords)
		if cell == null:
			return null
		cells.append(cell)
	if cells.is_empty():
		return null
	var building: Building = load(path).instantiate()
	building.build_order = entry.get("order", 0)
	var from: int = entry.get("from", -1)
	if from >= 0 and from < restored.size() and restored[from] != null and restored[from].is_coming_down():
		building.restore_from(restored[from])
	elif entry.get("moved", false):
		building.restore_moved(entry)
	match entry.get("state", "done"):
		"coming_down":
			grid.place(building, cells)
			if building is TownHall:
				(building as TownHall).restore_level(entry.get("level", 1))
			building.restore_coming_down(entry.get("left", {}))
		"waiting":
			building.put_down(grid, cells)
		"building":
			grid.place(building, cells)
			if building is Barn:
				(building as Barn).restore_plot_area()
			elif building is BarnPlot:
				(building as BarnPlot).join_barn_at(cells)
			building.restore_construction(entry.get("built", Building.EMPTY_STAGE), entry.get("banked", {}), entry.get("paused", false))
		_:
			grid.place(building, cells)
			if building is Barn:
				(building as Barn).restore_plot_area()
			elif building is BarnPlot:
				(building as BarnPlot).join_barn_at(cells)
			building.complete()
			while building.wanted_workers > entry.get("wanted_workers", building.wanted_workers):
				building.remove_worker_slot()
			if building is TownHall:
				(building as TownHall).restore_level(entry.get("level", 1))
				grid.keep_clear_around(building)
			if building is Storage:
				(building as Storage).restore_stock(entry.get("stock", 0))
			if building is Farm:
				(building as Farm).restore_growth(entry.get("growth", {}))
	JobSystem.note_build_order(building.build_order)
	return building


## Puts a builder's saved haul or store trip back on it. When that cannot be done, a drop it carried is put
## down where it stands, so nothing is lost.
func _restore_job(grid: Grid, meeple: Meeple, job: Dictionary, buildings: Array, drops: Array) -> void:
	var kind: String = job.get("kind", "")
	var carrying: bool = job.get("carrying", false)
	var done := false
	if ResourceDrop.SCENES.has(kind):
		var drop: ResourceDrop = _at(drops, job.get("drop", -1))
		if job["type"] == "store":
			done = StoreJob.resume_saved(meeple, _at(buildings, job.get("pile", -1)) as Storage, kind, carrying, drop)
		else:
			var site: Building = _at(buildings, job.get("site", -1))
			var old: Building = _at(buildings, job.get("from", -1))
			# A paused site still gets what is already carried to it.
			if site != null and site.is_under_construction() and (carrying or not site.is_paused()):
				done = HaulJob.resume_saved(meeple, site, kind, job.get("count", 1), carrying, job.get("taken", carrying), job.get("extra", false),
						old if old != null and old.is_coming_down() else null, _at(buildings, job.get("pile", -1)) as Storage, drop)
	if not done and carrying:
		for i in range(job.get("count", 1)):
			grid.add_drop(ResourceDrop.scene_of(kind), meeple.position)


## The item at `index` in `list`, or null.
func _at(list: Array, index: int) -> Variant:
	return list[index] if index >= 0 and index < list.size() else null


## Runs a frame after loading, once the level's own scripts placed the camera, so the saved view wins.
func _restore_camera(camera_data: Dictionary) -> void:
	if _grid == null or not is_instance_valid(_grid):
		return
	var camera := _grid.get_viewport().get_camera_2d()
	if camera == null:
		return
	camera.global_position = camera_data.get("position", camera.global_position)
	camera.zoom = camera_data.get("zoom", camera.zoom)
