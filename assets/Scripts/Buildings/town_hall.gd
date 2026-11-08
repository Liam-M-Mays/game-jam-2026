extends Hut
class_name TownHall

signal upgraded(new_level : int)

@export var meeples_required : Array[int] = [3, 6, 10, 15]

var _level := 1

static func find_town_hall() -> TownHall:
	var tree := Engine.get_main_loop() as SceneTree
	var best : TownHall = null
	for node in tree.get_nodes_in_group(Building.COMPLETED_GROUP):
		if node is TownHall and (best == null or node.level() > best.level()):
			best = node
	return best

static func current_level() -> int:
	var hall := find_town_hall()
	return hall.level() if hall != null else 1

func level() -> int:
	return _level

func max_level() -> int:
	return hframes - last_stage()

func is_max_level() -> bool:
	return _level >= max_level()

func meeples_for_next_level() -> int:
	if is_max_level() or meeples_required.is_empty():
		return 0
	return meeples_required[mini(_level - 1, meeples_required.size() - 1)]

func can_upgrade() -> bool:
	return not is_max_level() and JobSystem.workers.size() >= meeples_for_next_level()

func upgrade() -> bool:
	if _level >= max_level():
		return false
	_level += 1
	_show_frame(last_stage() + _level - 1)
	upgraded.emit(_level)
	return true

func level_icon(target_level : int) -> Texture2D:
	var sheet := region_rect if region_enabled else Rect2(Vector2.ZERO, texture.get_size())
	var cell_size := sheet.size / Vector2(hframes, vframes)
	var index := last_stage() + target_level - 1
	var cell := Vector2(index % hframes, floori(float(index) / hframes))
	var region := Rect2(sheet.position + cell * cell_size, cell_size)
	var image := texture.get_image()
	if image != null and not image.is_compressed():
		var used := image.get_region(Rect2i(region)).get_used_rect()
		if used.has_area():
			region = Rect2(region.position + Vector2(used.position), Vector2(used.size))
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas
