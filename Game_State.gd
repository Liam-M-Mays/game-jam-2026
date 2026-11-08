extends Node

signal hunger_changed(value: float)
signal starved
signal toast_requested(text: String)

const MAX_HUNGER := 100.0

var hunger_drain_per_second := 0.5

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


func feed(amount: float) -> void:
	hunger += amount


func toast(text: String) -> void:
	toast_requested.emit(text)
