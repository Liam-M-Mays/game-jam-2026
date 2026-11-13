extends RefCounted
class_name ResourceDrop
## One wood or stone, on the ground or carried, as plain data. Inventory keeps it, and it draws as one
## canvas item under Grid, the way a meeple does. Positions are in Grid's space, apart from `global_position`.

const LAND_ATTEMPTS := 8
const SCENES := {
	"wood": "res://assets/Scenes/Resources/Drops/wood.tscn",
	"stone": "res://assets/Scenes/Resources/Drops/rock.tscn",
}

var grid : Grid
var kind : String
var claimed := false
## True while it is loose, so Inventory keeps it in the search area of its kind.
var listed := false
var position : Vector2:
	set(value):
		if listed:
			Inventory.drop_moved(self, position, value)
		position = value
		if _item.is_valid():
			RenderingServer.canvas_item_set_transform(_item, Transform2D(0.0, _look.scale, 0.0, value))
var global_position : Vector2:
	get:
		return grid.to_global(position)
	set(value):
		position = grid.to_local(value)

var _look : DropLook
var _item : RID

## The scene of a drop of `drop_kind`, for `Grid.add_drop`.
static func scene_of(drop_kind : String) -> PackedScene:
	return load(SCENES[drop_kind])

func _init(owner : Grid, look : DropLook, at : Vector2) -> void:
	grid = owner
	kind = look.kind
	_look = look
	_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_item, owner.get_canvas_item())
	RenderingServer.canvas_item_set_z_index(_item, look.z_index)
	look.draw(_item)
	position = at

func show() -> void:
	if _item.is_valid():
		RenderingServer.canvas_item_set_visible(_item, true)

func hide() -> void:
	if _item.is_valid():
		RenderingServer.canvas_item_set_visible(_item, false)

## Takes the drop out of the world now, so the stock count is right in this same frame.
func consume() -> void:
	Inventory.unregister(self)
	free_item()

## True until it is consumed, or the grid leaves the game.
func is_in_world() -> bool:
	return _item.is_valid()

## Frees the canvas item. Inventory calls this for every drop when the grid leaves the game.
func free_item() -> void:
	if _item.is_valid():
		RenderingServer.free_rid(_item)
	_item = RID()

func launch() -> void:
	var tween := grid.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _pick_landing(), _look.launch_duration)

func _pick_landing() -> Vector2:
	for i in range(LAND_ATTEMPTS):
		var spot := position + Vector2.from_angle(randf() * TAU) * randf_range(_look.launch_distance_min, _look.launch_distance_max)
		var cell := grid.cell_at(grid.to_global(spot))
		if cell != null and cell.occupant == null:
			return spot
	return position
