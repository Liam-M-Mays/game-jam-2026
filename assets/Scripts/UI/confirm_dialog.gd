class_name ConfirmDialog
extends Control
## A small question box over the screen, in the settings menu's panel art, with two of Brady's buttons.
## Make one with `ConfirmDialog.ask`, then wait for `confirmed` or `cancelled`. It frees itself.

signal confirmed
signal cancelled

var _no: TextureButton


## Shows `question` over `parent` with a yes and a no button, named as in UiArt.
static func ask(parent: Node, question: String, yes_art: String, no_art: String) -> ConfirmDialog:
	var dialog := ConfirmDialog.new()
	dialog._build(question, yes_art, no_art)
	parent.add_child(dialog)
	InputMode.focus_default.call_deferred()
	return dialog


## The button InputMode highlights on a controller: the safe answer.
func default_focus_target() -> Control:
	return _no


func _build(question: String, yes_art: String, no_art: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	add_to_group(InputMode.DEFAULT_FOCUS)
	var dim := ColorRect.new()
	dim.color = PixelStyle.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiArt.frame("panel", Vector4(4, 4, 4, 4), Vector4(10, 8, 10, 8)))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8 * PixelStyle.PX)
	panel.add_child(column)
	var label := Label.new()
	label.text = question
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", PixelStyle.FONT_SIZE)
	label.add_theme_color_override("font_color", PixelStyle.TEXT)
	column.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8 * PixelStyle.PX)
	column.add_child(buttons)
	_no = UiArt.button(no_art)
	_no.pressed.connect(_answer.bind(false))
	buttons.add_child(_no)
	var yes := UiArt.button(yes_art)
	yes.pressed.connect(_answer.bind(true))
	buttons.add_child(yes)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer(false)


func _answer(yes: bool) -> void:
	if is_queued_for_deletion():
		return
	queue_free()
	if yes:
		confirmed.emit()
	else:
		cancelled.emit()
		InputMode.focus_default.call_deferred()
