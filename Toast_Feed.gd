class_name ToastFeed
extends VBoxContainer

@export var max_toasts := 9
@export var lifetime := 30.0
@export var fade_time := 4.0
@export var font: Font
@export var font_size := 32
@export var info_color := Color.WHITE
@export var tip_color := Color("ffe08a")
@export var warning_color := Color("ff6b5b")
@export var fact_color := Color("9fd8ff")
@export var tip_prefix := "Tip: "
@export var warning_prefix := ""
@export var fact_prefix := "Fun fact: "


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	alignment = BoxContainer.ALIGNMENT_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.toast_requested.connect(push)


func push(text: String, kind: int = 0) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match kind:
		GameState.ToastKind.TIP:
			label.text = tip_prefix + text
			label.add_theme_color_override("font_color", tip_color)
		GameState.ToastKind.FACT:
			label.text = fact_prefix + text
			label.add_theme_color_override("font_color", fact_color)
		GameState.ToastKind.WARNING:
			label.text = warning_prefix + text
			label.add_theme_color_override("font_color", warning_color)
		_:
			label.text = text
			label.add_theme_color_override("font_color", info_color)
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)

	while get_child_count() > max_toasts:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()

	var tween := label.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_interval(maxf(lifetime - fade_time, 0.0))
	tween.tween_property(label, "modulate:a", 0.0, fade_time)
	tween.tween_callback(label.queue_free)
