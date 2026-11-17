extends Sprite2D
class_name DropLook
## The look and the numbers of one kind of drop. Tweak them in its scene under Scenes/Resources/Drops.
## Grid keeps one copy of each scene, out of the tree, and draws every drop of that kind from it.

@export var kind := "wood"
@export var launch_distance_min := 30.0
@export var launch_distance_max := 80.0
@export var launch_duration := 0.35

## Draws this sprite into `item`, centred on the item's origin.
func draw(item : RID) -> void:
	var part := texture as AtlasTexture
	var size := part.region.size
	RenderingServer.canvas_item_add_texture_rect_region(item, Rect2(offset - size / 2, size), part.atlas.get_rid(), part.region)
