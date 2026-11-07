extends Node
## Autoload singleton. Add it in Project Settings > Globals > Autoload with the name "GameState".
## Anything in the game can read/change resources with GameState.wood += 1, etc.
## The HUD listens to the signals below, so you never touch UI from gameplay code.
 
signal resources_changed
signal hunger_changed(value: float)
signal starved
signal toast_requested(text: String)
 
const MAX_HUNGER := 100.0
 
## How fast hunger drops. 0.5/sec = full to empty in about 3 min 20 sec.
var hunger_drain_per_second := 0.5
 
var wood := 0:
	set(value):
		wood = maxi(value, 0)
		resources_changed.emit()
 
var stone := 0:
	set(value):
		stone = maxi(value, 0)
		resources_changed.emit()
 
var meeple := 0:
	set(value):
		meeple = maxi(value, 0)
		resources_changed.emit()
 
var hunger := MAX_HUNGER:
	set(value):
		var had_food := hunger > 0.0
		hunger = clampf(value, 0.0, MAX_HUNGER)
		hunger_changed.emit(hunger)
		if had_food and hunger == 0.0:
			starved.emit()
 
 
func _process(delta: float) -> void:
	# This node is "Pausable" (the default), so hunger stops
	# draining automatically whenever get_tree().paused is true.
	hunger -= hunger_drain_per_second * delta
 
 
## Call when starting a new game (the main menu's START button does this).
func reset() -> void:
	wood = 0
	stone = 0
	meeple = 0
	hunger = MAX_HUNGER
 
 
func feed(amount: float) -> void:
	hunger += amount
 
 
## cost looks like {"wood": 10, "stone": 5}; missing keys count as 0.
func can_afford(cost: Dictionary) -> bool:
	return wood >= cost.get("wood", 0) and stone >= cost.get("stone", 0)
 
 
## Returns true and subtracts the cost if affordable, otherwise does nothing.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	wood -= cost.get("wood", 0)
	stone -= cost.get("stone", 0)
	return true
 
 
## Show a toast notification from anywhere: GameState.toast("Found 3 logs")
func toast(text: String) -> void:
	toast_requested.emit(text)
