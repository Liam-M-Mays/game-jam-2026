extends Sprite2D
class_name MeepleLook
## The look and the numbers of every meeple. Tweak them in meeple.tscn.
## Grid keeps one copy of the scene, out of the tree, and draws each meeple from it.

const HEAD_ANIMATION := &"default"
const OUTLINE_SHADER := preload("res://assets/Shaders/outline.gdshader")

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

## One outline material for each part of the sheet, shared by every outlined meeple.
var _outline_materials : Dictionary[Rect2, ShaderMaterial] = {}

## Replaces what `item` draws with a body in `body_color` and the head frame `frame`, raised by `head_offset_y`.
func draw(item : RID, body_color : Color, frame : int, head_offset_y : float) -> void:
	var head : AnimatedSprite2D = $head
	RenderingServer.canvas_item_clear(item)
	_draw_part(item, texture, offset, body_color)
	var head_texture := head.sprite_frames.get_frame_texture(HEAD_ANIMATION, frame)
	_draw_part(item, head_texture, head.position + Vector2(0, head_offset_y), head.self_modulate)

## Draws the same meeple into `items`, its body into the first and its head into the second, each with
## the selected outline around it. A meeple's outline items sit behind its own item, so only the line shows.
func draw_outline(items : Array[RID], body_color : Color, frame : int, head_offset_y : float) -> void:
	var head : AnimatedSprite2D = $head
	var head_texture := head.sprite_frames.get_frame_texture(HEAD_ANIMATION, frame)
	var parts : Array[AtlasTexture] = [texture, head_texture]
	var centers : Array[Vector2] = [offset, head.position + Vector2(0, head_offset_y)]
	var colors : Array[Color] = [body_color, head.self_modulate]
	for i in range(items.size()):
		RenderingServer.canvas_item_clear(items[i])
		RenderingServer.canvas_item_set_material(items[i], _outline_material(parts[i]).get_rid())
		# The outline reaches past the part, so its UVs must not be clamped to the part. The shader keeps to it.
		_draw_part(items[i], parts[i], centers[i], colors[i], false)

## The outline shader looks only inside `region_rect`, so each part of the sheet gets its own material.
func _outline_material(part : AtlasTexture) -> ShaderMaterial:
	if _outline_materials.has(part.region):
		return _outline_materials[part.region]
	var size := part.atlas.get_size()
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("selected", true)
	material.set_shader_parameter("region_rect", Vector4(part.region.position.x / size.x, part.region.position.y / size.y,
			part.region.end.x / size.x, part.region.end.y / size.y))
	_outline_materials[part.region] = material
	return material

func _draw_part(item : RID, part : AtlasTexture, center : Vector2, color : Color, clip_uv := true) -> void:
	var size := part.region.size
	RenderingServer.canvas_item_add_texture_rect_region(item, Rect2(center - size / 2, size), part.atlas.get_rid(), part.region, color, false, clip_uv)
