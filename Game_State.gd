extends Node

enum ToastKind { INFO, TIP, WARNING, FACT }

signal hunger_changed(value: float)
signal starved
signal toast_requested(text: String, kind: int)
signal speed_changed(speed: float)

const MAX_HUNGER := 100.0
const FULL_FOOD_PER_MEEPLE := 5.0
const TOAST_REPEAT_COOLDOWN := 3.0
const SPEEDS: Array[float] = [1.0, 1.5, 2.0, 3.0]

var _last_toast_time := {}
var _tips_shown := {}
var _speed_index := 0

var speed: float:
	get:
		return SPEEDS[_speed_index]

var hunger := MAX_HUNGER:
	set(value):
		var had_food := hunger > 0.0
		hunger = clampf(value, 0.0, MAX_HUNGER)
		hunger_changed.emit(hunger)
		if had_food and hunger == 0.0:
			starved.emit()


func _ready() -> void:
	_connect_backend.call_deferred()


func _connect_backend() -> void:
	Inventory.changed.connect(_update_hunger)
	JobSystem.changed.connect(_update_hunger)
	_update_hunger()


func _update_hunger() -> void:
	var meeples := JobSystem.workers.size()
	var value := MAX_HUNGER
	if meeples > 0:
		value = Inventory.count("food") / (meeples * FULL_FOOD_PER_MEEPLE) * MAX_HUNGER
	value = clampf(value, 0.0, MAX_HUNGER)
	if not is_equal_approx(value, hunger):
		hunger = value


func new_game() -> void:
	Inventory.reset()
	JobSystem.reset()
	_last_toast_time.clear()
	_tips_shown.clear()
	set_speed_index(0)
	_update_hunger()


func set_speed_index(index: int) -> void:
	_speed_index = clampi(index, 0, SPEEDS.size() - 1)
	Engine.time_scale = speed
	speed_changed.emit(speed)


func cycle_speed() -> void:
	set_speed_index((_speed_index + 1) % SPEEDS.size())


func toast(text: String, kind: int = ToastKind.INFO) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_toast_time.get(text, -INF) < TOAST_REPEAT_COOLDOWN:
		return
	_last_toast_time[text] = now
	toast_requested.emit(text, kind)


func tip(text: String) -> void:
	toast(text, ToastKind.TIP)


func tip_once(id: String, text: String) -> void:
	if _tips_shown.has(id):
		return
	_tips_shown[id] = true
	tip(text)


func fact(text: String) -> void:
	toast(text, ToastKind.FACT)


func warn(text: String) -> void:
	toast(text, ToastKind.WARNING)
