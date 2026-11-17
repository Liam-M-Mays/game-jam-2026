extends Node
## Autoload `Settings`. Holds every player setting, saves them to user://settings.cfg
## and applies the ones the engine handles itself (window, frame rate, volume, brightness).
## Game scripts read the rest with `Settings.get_value()` or the helpers below,
## and can listen to `changed` to react while the game runs.

signal changed(key: StringName)

const PATH := "user://settings.cfg"
const SECTION := "settings"

const SFX_BUS := &"SFX"
const AMBIENT_BUS := &"Ambient"
const MUSIC_BUS := &"Music"

const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080", "2560x1440"]
const WINDOW_MODES := ["Windowed", "Borderless", "Fullscreen"]
const FRAME_RATES := ["30", "60", "120", "Unlimited"]
const SIZES := ["Small", "Medium", "Large"]
const SIZE_SCALES := {"Small": 0.75, "Medium": 1.0, "Large": 1.25}
const AUTO_SAVES := ["Every 5 min", "Every 10 min", "Off"]
const ACTION_STYLES := ["Hold", "Toggle"]
const COLORBLIND_MODES := ["Off", "Protanopia", "Deuteranopia", "Tritanopia"]
const LANGUAGES := ["English"]

## Every setting and its default. Sliders are 0 to 100, toggles are bools,
## and choices store the text of the chosen option.
const DEFAULTS := {
	&"resolution": "1920x1080",
	&"window_mode": "Windowed",
	&"vsync": true,
	&"brightness": 50,
	&"frame_rate": "Unlimited",
	&"screen_shake": true,
	&"hud_size": "Medium",
	&"master_volume": 100,
	&"music_volume": 100,
	&"sfx_volume": 100,
	&"ambient_volume": 100,
	&"mouse_sensitivity": 50,
	&"zoom_sensitivity": 50,
	&"controller_sensitivity": 50,
	&"invert_x": false,
	&"invert_y": false,
	&"vibration": true,
	&"action_style": "Hold",
	&"tutorials": true,
	&"auto_save": "Every 5 min",
	&"camera_sensitivity": 50,
	&"tips": true,
	&"fun_facts": true,
	&"auto_pause": true,
	&"text_size": "Medium",
	&"colorblind_mode": "Off",
	&"high_contrast": false,
	&"screen_reader": false,
	&"language": "English",
}

const CONTROLS_KEYS: Array[StringName] = [
	&"mouse_sensitivity", &"zoom_sensitivity", &"controller_sensitivity",
	&"invert_x", &"invert_y", &"vibration", &"action_style",
]

## How far the brightness overlay darkens at 0 and lightens at 100.
const MAX_DARKEN := 0.6
const MAX_LIGHTEN := 0.25

var _values := {}
var _brightness_rect := ColorRect.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_values = DEFAULTS.duplicate()
	_load()
	_add_bus(SFX_BUS)
	_add_bus(AMBIENT_BUS)
	_setup_brightness()
	# The Music autoload makes its bus after this one runs, so apply once every autoload is ready.
	_apply_all.call_deferred()


func get_value(key: StringName) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: StringName, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key)
	_save()
	changed.emit(key)


func reset(keys: Array[StringName] = []) -> void:
	var targets: Array = keys if not keys.is_empty() else DEFAULTS.keys()
	for key: StringName in targets:
		set_value(key, DEFAULTS[key])


## Turns a 0 to 100 slider into a speed multiplier: 0 is half speed, 50 is normal, 100 is double.
func multiplier(key: StringName) -> float:
	return pow(2.0, (float(get_value(key)) - 50.0) / 50.0)


func hud_scale() -> float:
	return SIZE_SCALES.get(get_value(&"hud_size"), 1.0)


func text_scale() -> float:
	return SIZE_SCALES.get(get_value(&"text_size"), 1.0)


func toggle_actions() -> bool:
	return get_value(&"action_style") == "Toggle"


func _apply_all() -> void:
	for key: StringName in DEFAULTS:
		_apply(key)


func _apply(key: StringName) -> void:
	match key:
		&"resolution", &"window_mode":
			_apply_window()
		&"vsync":
			if _has_window():
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value(key) else DisplayServer.VSYNC_DISABLED)
		&"frame_rate":
			var rate: String = get_value(key)
			Engine.max_fps = 0 if rate == "Unlimited" else rate.to_int()
		&"brightness":
			_apply_brightness()
		&"master_volume":
			_set_bus_volume(&"Master", VillageAudio.MASTER_VOLUME * _volume(key))
		&"music_volume":
			_set_bus_volume(MUSIC_BUS, _volume(key))
		&"sfx_volume":
			_set_bus_volume(SFX_BUS, _volume(key))
		&"ambient_volume":
			_set_bus_volume(AMBIENT_BUS, _volume(key))


func _apply_window() -> void:
	if not _has_window():
		return
	match get_value(&"window_mode"):
		"Fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"Borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var parts: PackedStringArray = str(get_value(&"resolution")).split("x")
			var wanted := Vector2i(parts[0].to_int(), parts[1].to_int())
			var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			var window_size := wanted.min(screen.size)
			DisplayServer.window_set_size(window_size)
			DisplayServer.window_set_position(screen.position + (screen.size - window_size) / 2)


## The editor's embedded game view and headless runs (CI) own their window, so leave it alone there.
func _has_window() -> bool:
	return DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor()


func _setup_brightness() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_brightness_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brightness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_brightness_rect)


func _apply_brightness() -> void:
	var amount := (float(get_value(&"brightness")) - 50.0) / 50.0
	var material := CanvasItemMaterial.new()
	if amount >= 0.0:
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_brightness_rect.color = Color(1, 1, 1, amount * MAX_LIGHTEN)
	else:
		_brightness_rect.color = Color(0, 0, 0, -amount * MAX_DARKEN)
	_brightness_rect.material = material
	_brightness_rect.visible = not is_zero_approx(amount)


## Squared so the slider feels even to the ear: 50% is clearly half as loud, not barely quieter.
func _volume(key: StringName) -> float:
	var value := float(get_value(key)) / 100.0
	return value * value


func _add_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		AudioServer.set_bus_volume_linear(index, linear)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for key: StringName in DEFAULTS:
		var value: Variant = config.get_value(SECTION, key, DEFAULTS[key])
		if typeof(value) == typeof(DEFAULTS[key]):
			_values[key] = value


func _save() -> void:
	var config := ConfigFile.new()
	for key: StringName in _values:
		config.set_value(SECTION, key, _values[key])
	config.save(PATH)
