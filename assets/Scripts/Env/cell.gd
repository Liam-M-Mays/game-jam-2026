extends Sprite2D
class_name Cell

const HIGHLIGHT_COLOR := Color(0.4, 0.4, 0.4)

var occupant : GridObject = null

func highlight(alpha : float) -> void:
	modulate = Color(HIGHLIGHT_COLOR, alpha)
