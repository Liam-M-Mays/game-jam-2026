class_name DevSettings
extends Resource
## Values a developer changes while building the game.
##
## The saved values are in [code]dev_settings.tres[/code], next to this file.
## Change them there, not in code. Read them with [method load_settings].

## Where the saved values are.
const PATH := "res://game/core/dev_settings.tres"

## How many cells the ground world has, roughly. The world is round, so the
## real count differs a little.
@export_range(500, 1000000, 1) var world_cells: int = 100000

## How many times a second the simulation steps at normal game speed.
@export_range(1, 120, 1) var ticks_per_second: int = 20


## Returns the saved dev settings.
static func load_settings() -> DevSettings:
	return load(PATH) as DevSettings
