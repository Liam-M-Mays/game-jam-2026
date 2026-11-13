extends CanvasLayer
class_name ConstructionTooltip

const LAYER := 10
const MOUSE_OFFSET := Vector2(24, 24)
const FONT_SIZE := 24
const STUCK_COLOR := "ff6b6b"
const PAUSED_COLOR := "ffd91a"

## Shown next to the cursor in place of a site's needs. The build system sets it while placing.
var note := ""
var _panel : PanelContainer
var _label : RichTextLabel

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_label.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	_panel.add_child(_label)
	add_child(_panel)
	_panel.hide()

func _process(_delta : float) -> void:
	var text := _text()
	if text.is_empty():
		_panel.hide()
		return
	_label.text = text
	_panel.show()
	_panel.reset_size()
	var screen := get_viewport().get_visible_rect().size
	var pos := get_viewport().get_mouse_position() + MOUSE_OFFSET
	_panel.position = pos.clamp(Vector2.ZERO, (screen - _panel.size).max(Vector2.ZERO))

static func describe(site : Building) -> String:
	var lines := ["[b]%s[/b]" % site.display_name(), "Built %d / %d" % [site.built_stage() + 1, site.last_stage() + 1], "Next stage needs:"]
	var stuck := site.missing()
	var needs := site.next_stage_needs()
	for kind in needs:
		var line := "  %d %s" % [needs[kind], kind]
		if stuck.has(kind):
			line = "[color=#%s]%s  (not enough)[/color]" % [STUCK_COLOR, line]
		lines.append(line)
	if site.is_paused():
		lines.append("[color=#%s]Paused - right-click to resume[/color]" % PAUSED_COLOR)
	return "\n".join(lines)

## How full a finished pile is, shown while the mouse is over it.
static func describe_pile(pile : Storage) -> String:
	return "[b]%s[/b]\nHolds %d / %d %s" % [pile.display_name(), pile.held(), pile.capacity(), pile.kind]

func _text() -> String:
	if get_tree().paused or get_viewport().gui_get_hovered_control() != null:
		return ""
	if not note.is_empty():
		return note
	var site := site_under_mouse(get_tree())
	if site != null:
		return describe(site)
	var pile := pile_under_mouse(get_tree())
	return describe_pile(pile) if pile != null else ""

static func site_under_mouse(tree : SceneTree) -> Building:
	return _under_mouse(tree, Building.CONSTRUCTION_GROUP)

## The finished pile under the mouse, so hovering it shows how full it is.
static func pile_under_mouse(tree : SceneTree) -> Storage:
	return _under_mouse(tree, Storage.GROUP) as Storage

static func _under_mouse(tree : SceneTree, group : StringName) -> Building:
	var best : Building = null
	for site : Building in tree.get_nodes_in_group(group):
		if not site.is_visible_in_tree() or not site.get_rect().has_point(site.get_local_mouse_position()):
			continue
		if best == null or site.global_position.y > best.global_position.y:
			best = site
	return best
