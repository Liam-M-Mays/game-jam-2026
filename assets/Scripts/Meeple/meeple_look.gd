extends Sprite2D
class_name MeepleLook
## The look and the numbers of every meeple. Tweak them in meeple.tscn.
## Grid keeps one copy of the scene, out of the tree, and draws each meeple from it.

const HEAD_ANIMATION := &"default"

@export var speed := 100
@export var y_stretch := 0.1
@export var stretch_speed := 0.25
@export var wobble := 10
@export var wobble_speed := 1.5
@export var wander_radius := 60.0
@export var wander_speed := 30
@export var wander_pause_min := 1.0
@export var wander_pause_max := 3.5
@export var wander_ring := 2
@export var building_hop_chance := 0.15
@export var topple_time := 0.45
@export var corpse_linger := 0.6
@export var fade_time := 0.8

## Replaces what `item` draws with a body in `body_color` and the head frame `frame`, raised by `head_offset_y`.
func draw(item : RID, body_color : Color, frame : int, head_offset_y : float) -> void:
	var head : AnimatedSprite2D = $head
	RenderingServer.canvas_item_clear(item)
	_draw_part(item, texture, offset, body_color)
	var head_texture := head.sprite_frames.get_frame_texture(HEAD_ANIMATION, frame)
	_draw_part(item, head_texture, head.position + Vector2(0, head_offset_y), head.self_modulate)

func _draw_part(item : RID, part : AtlasTexture, center : Vector2, color : Color) -> void:
	var size := part.region.size
	RenderingServer.canvas_item_add_texture_rect_region(item, Rect2(center - size / 2, size), part.atlas.get_rid(), part.region, color)
