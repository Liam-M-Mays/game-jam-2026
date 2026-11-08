class_name BuildTooltip
extends PanelContainer

@export var label: Label
@export var mouse_offset := Vector2(24, 24)

var _build_system: BuildSystem
var _sites: Array[Building] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if label:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func setup(build_system: BuildSystem) -> void:
	_build_system = build_system
	build_system.building_placed.connect(_on_building_placed)
	build_system.building_completed.connect(_forget)


func _process(_delta: float) -> void:
	var site = _hovered_site()
	if site == null:
		hide()
		return
	label.text = _describe(site)
	show()
	reset_size()
	_follow_mouse()


func _on_building_placed(site: Building) -> void:
	_sites.append(site)
	site.tree_exiting.connect(_forget.bind(site))


func _forget(site: Building) -> void:
	_sites.erase(site)


func _hovered_site():
	if _build_system == null or _build_system.is_building() or get_tree().paused:
		return null
	var mouse := _build_system.get_global_mouse_position()
	for i in range(_sites.size() - 1, -1, -1):
		var site = _sites[i]
		if not is_instance_valid(site):
			_sites.remove_at(i)
			continue
		if site.get_rect().has_point(site.to_local(mouse)):
			return site
	return null


func _describe(site: Building) -> String:
	var lines := [
		site.display_name(),
		"Built %d / %d" % [site.built_stage() + 1, site.last_stage() + 1],
	]
	var needs := site.next_stage_needs()
	if needs.is_empty():
		lines.append("Building...")
	else:
		var parts := []
		for kind in needs:
			parts.append("%d %s" % [needs[kind], kind])
		lines.append("Next stage: " + ", ".join(parts))
	return "\n".join(lines)


func _follow_mouse() -> void:
	var screen := get_viewport().get_visible_rect().size
	var pos := get_viewport().get_mouse_position() + mouse_offset
	pos.x = minf(pos.x, screen.x - size.x)
	pos.y = minf(pos.y, screen.y - size.y)
	position = pos
