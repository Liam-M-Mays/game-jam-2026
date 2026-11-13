extends Resource
class_name VillageRules
## The village's food and growth numbers. Tune them in assets/Res/village_rules.tres.
## Population, Inventory and the food bar read them.

## What a new game starts with.
@export var start_stock : Dictionary[String, int] = {"food": 10}
## The food the village holds with no silo.
@export var base_food_cap := 20
## How much food one meeple needs for a full food bar.
@export var food_per_meeple := 2.0
## Under this much of the food bar (0 to 100), meeples can starve.
@export var starve_below := 25.0
## Over this much of the food bar (0 to 100), a new meeple can move into a hut with room.
@export var grow_above := 50.0
## Seconds between two starving checks.
@export var starve_tick := 4.0
## The chance that one meeple dies at each starving check.
@export_range(0.0, 1.0, 0.01) var death_chance := 0.25
## A new meeple moves in after a random wait between these two, in seconds.
@export var grow_min_delay := 8.0
@export var grow_max_delay := 16.0
