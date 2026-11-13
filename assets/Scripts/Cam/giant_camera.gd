extends CameraControls
class_name GiantCamera
## The camera on the giant. The view stays inside the wide view at `wide_position`.

@export var wide_position := Vector2(47, -86)

func _process(delta: float) -> void:
	super(delta)
	_keep_inside_wide_view()

func _keep_inside_wide_view() -> void:
	var slack := get_viewport_rect().size * 0.5 * (1.0 / min_zoom - 1.0 / zoom.x)
	var clamped := global_position.clamp(wide_position - slack, wide_position + slack)
	top_level = is_zoomed_out()
	global_position = clamped
