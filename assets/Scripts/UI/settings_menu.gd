class_name SettingsMenu
extends Control
## The tabbed settings screen. It builds its nodes in code, so its scene file only holds the root
## and the shared scenes (main menu, HUD) only gain one instance each.
## Tabs, panel and the labelled buttons use Brady's art (see UiArt). The active tab is the
## panel-colored one that joins the panel; the others are the darker tab.
## Every change goes straight to the Settings autoload, which saves it.

signal closed

const MAIN_MENU_SCENE := "res://Main_Menu.tscn"
const TABS := ["display", "audio", "controls", "gameplay", "other"]
const PANEL_SIZE := Vector2(1600, 840)
const CONTROL_WIDTH := 540
const ROW_HEIGHT := 60
const CONFIRM_SECONDS := 3.0
const PX := PixelStyle.PX

const CREDITS_TEXT := "Mason Paccadolmi - Artwork and Animation\nLiam Mays - Lead Programmer\nBrady Stewart - UI designer, programmer\nAidan Alegado - Music"
const PRIVACY_TEXT := "Mighty Meeple doesn't collect, track or send any of your data.\n\nYour settings are saved only on this computer."
const KEYS_TEXT := "Move camera: W A S D\nZoom: Q and E, or the mouse wheel\nDrag the camera: right mouse button\nGame speed: F\nPlace buildings: 1 to 9, 0 and -\nPause: Esc\n\nChanging keys is coming soon."

## Shows "Return to main menu" in the Other tab. Turn it on for the copy in the HUD.
@export var in_game := false

var _current := 0
var _info_open := false
var _tab_frames: Array[PanelContainer] = []
var _tab_buttons: Array[TextureButton] = []
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _back_button: TextureButton
var _rows_margin: MarginContainer
## True when the menu was opened straight onto an info page (the main menu's CREDITS button),
## so BACK closes the menu instead of going to a tab.
var _close_on_back := false
## The button that opened the menu, so a controller lands back on it after closing.
var _opener: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	add_to_group(InputMode.DEFAULT_FOCUS)
	hide()


func open() -> void:
	_opener = get_viewport().gui_get_focus_owner()
	show()
	_close_on_back = false
	_show_tab(_current)
	# Only highlight a button when the player is on a keyboard or controller.
	get_viewport().gui_release_focus()
	InputMode.focus_default()


## Opens the menu on the credits page, the same one as Other > Credits.
func open_credits() -> void:
	_opener = get_viewport().gui_get_focus_owner()
	show()
	_show_info("CREDITS", CREDITS_TEXT)
	_close_on_back = true
	get_viewport().gui_release_focus()
	InputMode.focus_default()


func close() -> void:
	_close_on_back = false
	hide()
	closed.emit()
	if is_instance_valid(_opener) and _opener.is_visible_in_tree() and not InputMode.using_mouse:
		_opener.grab_focus()
	else:
		InputMode.focus_default.call_deferred()


## The button InputMode highlights when a controller is in use.
func default_focus_target() -> Control:
	return _back_button if _info_open else _tab_buttons[_current]


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
	elif event is InputEventJoypadButton and event.pressed:
		# The shoulder buttons flip between tabs.
		if event.button_index == JOY_BUTTON_START:
			get_viewport().set_input_as_handled()
			close()
			return
		var step := 0
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
		if step != 0:
			get_viewport().set_input_as_handled()
			_show_tab(posmod(_current + step, TABS.size()))
			_tab_buttons[_current].grab_focus()


func _on_back_pressed() -> void:
	if _info_open and not _close_on_back:
		_show_tab(_current)
	else:
		close()


# --- Layout -------------------------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = PixelStyle.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Negative separation pulls the tabs down one art pixel so the active tab covers the panel's top edge.
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = PANEL_SIZE.x
	column.add_theme_constant_override("separation", -PX)
	center.add_child(column)

	var tab_margin := MarginContainer.new()
	tab_margin.add_theme_constant_override("margin_left", 3 * PX)
	tab_margin.add_theme_constant_override("margin_right", 3 * PX)
	tab_margin.z_index = 1
	column.add_child(tab_margin)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", PX)
	tab_margin.add_child(tab_row)
	for i in TABS.size():
		var frame := PanelContainer.new()
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.size_flags_vertical = Control.SIZE_SHRINK_END
		tab_row.add_child(frame)
		var button := UiArt.button(TABS[i])
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_show_tab.bind(i))
		frame.add_child(button)
		_tab_frames.append(frame)
		_tab_buttons.append(button)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = PANEL_SIZE.y
	panel.add_theme_stylebox_override("panel", UiArt.frame("panel", Vector4(4, 4, 4, 4), Vector4(8, 6, 8, 6)))
	column.add_child(panel)

	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 3 * PX)
	panel.add_child(inside)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_style_scrollbar(_scroll.get_v_scroll_bar())
	inside.add_child(_scroll)

	# Leaves room for the scrollbar so it never covers the controls on long tabs.
	_rows_margin = MarginContainer.new()
	_rows_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows_margin)
	_scroll.get_v_scroll_bar().visibility_changed.connect(_fit_scrollbar)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 0)
	_rows_margin.add_child(_rows)

	var footer := HBoxContainer.new()
	inside.add_child(footer)
	var hint := _label("Changes save automatically", PixelStyle.TEXT_MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	_back_button = UiArt.button("back")
	_back_button.pressed.connect(_on_back_pressed)
	footer.add_child(_back_button)


func _style_tabs() -> void:
	# The tab art is 29 pixels tall and a button is 23, so 3 pixels of tab show above and below it.
	var active_style := UiArt.frame("tab_active", Vector4(3, 3, 3, 1), Vector4(2, 3, 2, 3))
	var inactive_style := UiArt.frame("tab", Vector4(3, 3, 3, 1), Vector4(2, 3, 2, 3))
	for i in TABS.size():
		var active := i == _current and not _info_open
		_tab_frames[i].add_theme_stylebox_override("panel", active_style if active else inactive_style)


func _style_scrollbar(bar: VScrollBar) -> void:
	bar.add_theme_stylebox_override("scroll", PixelStyle.stylebox(PixelStyle.box(PixelStyle.TAB, [PixelStyle.OUTLINE]), 1, Vector4(0, 0, 0, 0)))
	var grabber := PixelStyle.stylebox(PixelStyle.box(PixelStyle.BUTTON, [PixelStyle.OUTLINE]), 1, Vector4(0, 0, 0, 0))
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber)
	bar.add_theme_stylebox_override("grabber_pressed", grabber)
	bar.custom_minimum_size.x = 6 * PX


func _fit_scrollbar() -> void:
	var bar := _scroll.get_v_scroll_bar()
	_rows_margin.add_theme_constant_override("margin_right", int(bar.custom_minimum_size.x) + 3 * PX if bar.visible else 0)


# --- Tabs ---------------------------------------------------------------------------------------

func _show_tab(index: int) -> void:
	_current = index
	_info_open = false
	_close_on_back = false
	_style_tabs()
	_clear_rows()
	match TABS[index]:
		"display":
			_choice("Resolution", &"resolution", Settings.RESOLUTIONS)
			_choice("Window mode", &"window_mode", Settings.WINDOW_MODES)
			_toggle("VSync", &"vsync")
			_slider("Brightness", &"brightness")
			_choice("Frame rate limit", &"frame_rate", Settings.FRAME_RATES)
			_toggle("Screen shake", &"screen_shake")
			_choice("HUD size", &"hud_size", Settings.SIZES)
		"audio":
			_slider("Master volume", &"master_volume")
			_slider("Music", &"music_volume")
			_slider("Sound effects", &"sfx_volume")
			_slider("Ambient", &"ambient_volume")
		"controls":
			_action("Key bindings", "VIEW", _show_info.bind("KEY BINDINGS", KEYS_TEXT))
			_slider("Mouse sensitivity", &"mouse_sensitivity")
			_slider("Zoom sensitivity", &"zoom_sensitivity")
			_slider("Controller sensitivity", &"controller_sensitivity")
			_toggle("Invert X axis", &"invert_x")
			_toggle("Invert Y axis", &"invert_y")
			_toggle("Controller vibration", &"vibration")
			_choice("Camera drag", &"action_style", Settings.ACTION_STYLES)
			_action("Reset controls", "RESET", _reset_controls, true)
		"gameplay":
			_toggle("Tutorials", &"tutorials")
			_choice("Auto-save", &"auto_save", Settings.AUTO_SAVES)
			_slider("Camera sensitivity", &"camera_sensitivity")
			_toggle("Tips and warnings", &"tips")
			_toggle("Fun facts", &"fun_facts")
			_toggle("Pause when unfocused", &"auto_pause")
			_header("ACCESSIBILITY")
			_choice("Text size", &"text_size", Settings.SIZES)
			_choice("Colorblind mode", &"colorblind_mode", Settings.COLORBLIND_MODES)
			_toggle("High contrast", &"high_contrast")
			_toggle("Screen reader", &"screen_reader")
		"other":
			_choice("Language", &"language", Settings.LANGUAGES)
			_action("Credits", "VIEW", _show_info.bind("CREDITS", CREDITS_TEXT))
			_action("Privacy", "VIEW", _show_info.bind("PRIVACY", PRIVACY_TEXT))
			_action("Reset all settings", "RESET", _reset_all, true)
			if in_game:
				_action("Return to main menu", "MENU", _go_to_main_menu)
			_action("Quit game", "QUIT", get_tree().quit, true)
	_scroll.scroll_vertical = 0


func _show_info(title: String, body: String) -> void:
	_info_open = true
	_style_tabs()
	_clear_rows()
	_header(title)
	var text := _label(body, PixelStyle.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(text)
	if not InputMode.using_mouse:
		_back_button.grab_focus()


func _reset_controls() -> void:
	Settings.reset(Settings.CONTROLS_KEYS)
	_show_tab(_current)


func _reset_all() -> void:
	Settings.reset()
	_show_tab(_current)


func _go_to_main_menu() -> void:
	SceneFader.change_scene(MAIN_MENU_SCENE)


# --- Rows ---------------------------------------------------------------------------------------

func _clear_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()


## Adds a labelled row and returns the box on its right where the control goes.
func _row(text: String) -> HBoxContainer:
	if _rows.get_child_count() > 0 and not _rows.get_child(-1) is Label:
		var line := ColorRect.new()
		line.color = PixelStyle.DIVIDER
		line.custom_minimum_size.y = PX
		_rows.add_child(line)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	_rows.add_child(row)
	var label := _label(text, PixelStyle.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var holder := HBoxContainer.new()
	holder.custom_minimum_size.x = CONTROL_WIDTH
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_theme_constant_override("separation", 2 * PX)
	row.add_child(holder)
	return holder


func _header(text: String) -> void:
	var label := _label(text, PixelStyle.ACCENT)
	label.custom_minimum_size.y = ROW_HEIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_rows.add_child(label)


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", PixelStyle.FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	return label


func _slider(text: String, key: StringName) -> void:
	var holder := _row(text)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = Settings.get_value(key)
	slider.custom_minimum_size = Vector2(CONTROL_WIDTH - 110, 10 * PX)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := PixelStyle.stylebox(PixelStyle.box(PixelStyle.TAB, [PixelStyle.OUTLINE]), 1, Vector4(0, 2, 0, 2))
	var fill := PixelStyle.stylebox(PixelStyle.box(PixelStyle.BUTTON, [PixelStyle.OUTLINE], PixelStyle.BUTTON_LIP, 1), 1, Vector4(0, 2, 0, 2))
	# Sliders have no focus style in Godot, so a focused slider swaps to a track with the white halo.
	var track_focused := PixelStyle.stylebox(PixelStyle.box(PixelStyle.TAB, [PixelStyle.HALO, PixelStyle.OUTLINE]), 2, Vector4(-1, 1, -1, 1))
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var fill_focused := PixelStyle.stylebox(PixelStyle.box(PixelStyle.BUTTON, [PixelStyle.HALO, PixelStyle.OUTLINE], PixelStyle.BUTTON_LIP, 1), 2, Vector4(-1, 1, -1, 1))
	slider.focus_entered.connect(func() -> void:
		slider.add_theme_stylebox_override("slider", track_focused)
		slider.add_theme_stylebox_override("grabber_area", fill_focused)
		slider.add_theme_stylebox_override("grabber_area_highlight", fill_focused))
	slider.focus_exited.connect(func() -> void:
		slider.add_theme_stylebox_override("slider", track)
		slider.add_theme_stylebox_override("grabber_area", fill)
		slider.add_theme_stylebox_override("grabber_area_highlight", fill))
	slider.add_theme_icon_override("grabber", PixelStyle.box(PixelStyle.TEXT, [PixelStyle.OUTLINE]))
	slider.add_theme_icon_override("grabber_highlight", PixelStyle.box(Color.WHITE, [PixelStyle.OUTLINE]))
	holder.add_child(slider)
	var readout := _label(str(int(slider.value)), PixelStyle.TEXT)
	readout.custom_minimum_size.x = 90
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	holder.add_child(readout)
	slider.value_changed.connect(func(value: float) -> void:
		readout.text = str(int(value))
		Settings.set_value(key, int(value)))


func _toggle(text: String, key: StringName) -> void:
	var holder := _row(text)
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size.x = 40 * PX
	_style_toggle(button)
	button.set_pressed_no_signal(Settings.get_value(key))
	button.text = "ON" if button.button_pressed else "OFF"
	button.toggled.connect(func(on: bool) -> void:
		button.text = "ON" if on else "OFF"
		Settings.set_value(key, on))
	holder.add_child(button)


## Off looks like an empty dark slot, on looks like a lit terracotta button.
func _style_toggle(button: Button) -> void:
	var none := Color.TRANSPARENT
	var outline := PixelStyle.OUTLINE
	var off := PixelStyle.stylebox(PixelStyle.box(PixelStyle.TAB, [none, outline]), 2)
	var off_hover := PixelStyle.stylebox(PixelStyle.box(PixelStyle.TAB, [PixelStyle.HALO, outline]), 2)
	var on := PixelStyle.stylebox(PixelStyle.box(PixelStyle.BUTTON, [none, outline], PixelStyle.BUTTON_LIP, 1), 2)
	var on_hover := PixelStyle.stylebox(PixelStyle.box(PixelStyle.BUTTON, [PixelStyle.HALO, outline], PixelStyle.BUTTON_LIP, 1), 2)
	button.add_theme_stylebox_override("normal", off)
	button.add_theme_stylebox_override("hover", off_hover)
	button.add_theme_stylebox_override("pressed", on)
	button.add_theme_stylebox_override("hover_pressed", on_hover)
	button.add_theme_stylebox_override("focus", PixelStyle.focus_ring())
	button.add_theme_font_size_override("font_size", PixelStyle.FONT_SIZE)
	button.add_theme_color_override("font_color", PixelStyle.TEXT_MUTED)
	button.add_theme_color_override("font_hover_color", PixelStyle.TEXT)
	button.add_theme_color_override("font_focus_color", PixelStyle.TEXT_MUTED)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)


func _choice(text: String, key: StringName, options: Array) -> void:
	var holder := _row(text)
	var index := maxi(options.find(Settings.get_value(key)), 0)
	var left := Button.new()
	left.text = "<"
	PixelStyle.style_button(left)
	var value := _label(options[index], PixelStyle.TEXT)
	value.custom_minimum_size.x = 75 * PX
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var right := Button.new()
	right.text = ">"
	PixelStyle.style_button(right)
	# Lambdas copy local variables, so read the current choice back from Settings each press.
	var step := func(by: int) -> void:
		var next := posmod(maxi(options.find(Settings.get_value(key)), 0) + by, options.size())
		value.text = options[next]
		Settings.set_value(key, options[next])
	left.pressed.connect(step.bind(-1))
	right.pressed.connect(step.bind(1))
	holder.add_child(left)
	holder.add_child(value)
	holder.add_child(right)


## A button on the right of the row. Risky actions ask "SURE?" first and need a second press.
func _action(text: String, button_text: String, callback: Callable, risky := false) -> void:
	var holder := _row(text)
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size.x = 40 * PX
	if risky:
		PixelStyle.style_button(button, PixelStyle.DANGER, PixelStyle.DANGER_LIP)
	else:
		PixelStyle.style_button(button)
	button.pressed.connect(func() -> void:
		if not risky or button.text == "SURE?":
			callback.call()
			return
		button.text = "SURE?"
		await get_tree().create_timer(CONFIRM_SECONDS, true, false, true).timeout
		if is_instance_valid(button):
			button.text = button_text)
	holder.add_child(button)
