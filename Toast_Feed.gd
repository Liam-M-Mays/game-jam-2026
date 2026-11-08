class_name ToastFeed
extends VBoxContainer

@export var max_toasts := 9
@export var lifetime := 30.0
@export var fade_time := 4.0
@export var font: Font
@export var font_size := 32
@export var backplate: StyleBox
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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	add_child(label)
	if backplate:
		label.add_theme_stylebox_override("normal", backplate)
		_shrink_to_text(label)

	while get_child_count() > max_toasts:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()

	var tween := label.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_interval(maxf(lifetime - fade_time, 0.0))
	tween.tween_property(label, "modulate:a", 0.0, fade_time)
	tween.tween_callback(label.queue_free)


func _shrink_to_text(label: Label) -> void:
	var text_width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var plate_width := ceilf(text_width) + 1.0 + backplate.get_margin(SIDE_LEFT) + backplate.get_margin(SIDE_RIGHT)
	label.custom_minimum_size.x = minf(plate_width, size.x)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
