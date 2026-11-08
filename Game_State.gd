extends Node

enum ToastKind { INFO, TIP, WARNING }

signal hunger_changed(value: float)
signal starved
signal toast_requested(text: String, kind: int)

const MAX_HUNGER := 100.0
const TOAST_REPEAT_COOLDOWN := 3.0

var hunger_drain_per_second := 0.5
var _last_toast_time := {}

var hunger := MAX_HUNGER:
	set(value):
		var had_food := hunger > 0.0
		hunger = clampf(value, 0.0, MAX_HUNGER)
		hunger_changed.emit(hunger)
		if had_food and hunger == 0.0:
			starved.emit()


func _process(delta: float) -> void:
	hunger -= hunger_drain_per_second * delta


func new_game() -> void:
	Inventory.reset()
	JobSystem.reset()
	hunger = MAX_HUNGER
	_last_toast_time.clear()


func feed(amount: float) -> void:
	hunger += amount


func toast(text: String, kind: int = ToastKind.INFO) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_toast_time.get(text, -INF) < TOAST_REPEAT_COOLDOWN:
		return
	_last_toast_time[text] = now
	toast_requested.emit(text, kind)


func tip(text: String) -> void:
	toast(text, ToastKind.TIP)


func warn(text: String) -> void:
	toast(text, ToastKind.WARNING)
