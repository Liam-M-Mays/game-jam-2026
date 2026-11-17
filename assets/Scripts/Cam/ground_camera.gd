extends CameraControls
## The camera on the ground. The middle of the view stays far enough inside the round world that you
## can't pan off it. The zoom-out limit is `min_zoom`, a dev setting on this node.

## The outline of the round world, whose points go round the middle one degree apart.
@export var world_edge : Polygon2D

func _process(delta: float) -> void:
	super(delta)
	_keep_inside_world()

func _keep_inside_world() -> void:
	var edge := world_edge.polygon
	if edge.is_empty():
		return
	var offset := global_position - world_edge.global_position
	var edge_distance := edge[posmod(roundi(offset.angle() / TAU * edge.size()), edge.size())].length()
	var half_view := get_viewport_rect().size * 0.5 / zoom.x
	var limit := maxf(edge_distance - minf(half_view.x, half_view.y), 0.0)
	if offset.length() > limit:
		global_position = world_edge.global_position + offset.limit_length(limit)
