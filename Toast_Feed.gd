class_name ToastFeed
extends VBoxContainer
## Attach to the ToastFeed VBoxContainer in the HUD (anchored bottom-left).
## Newest toast appears at the bottom and pushes older ones up.

@export var max_toasts := 9
@export var lifetime := 30.0  ## total seconds on screen
@export var fade_time := 4.0  ## the last N seconds are spent fading out; set = lifetime for a slow, gradual fade
@export var font: Font  ## drop your pixel .ttf here (optional)
@export var font_size := 32


func _ready() -> void:
	# Toasts freeze while the game is paused (the HUD itself runs ALWAYS).
	process_mode = Node.PROCESS_MODE_PAUSABLE
	alignment = BoxContainer.ALIGNMENT_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN  # grows upward from the bottom edge
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.toast_requested.connect(push)


func push(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)  # last child = bottom of the stack

	# Too many on screen? Drop the oldest (top) ones to make room.
	while get_child_count() > max_toasts:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()

	# Wait, fade, then delete. The tween is tied to the label, so it pauses with the game.
	var tween := label.create_tween()
	tween.tween_interval(maxf(lifetime - fade_time, 0.0))
	tween.tween_property(label, "modulate:a", 0.0, fade_time)
	tween.tween_callback(label.queue_free)
var _test_count := 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_test_count += 1
		GameState.toast("Test toast %d" % _test_count)
