class_name VillagePart
extends RefCounted
## One part of a village that is not the grid: stock, the job board, the
## meeples, the buildings.
##
## A part is hung on a village with [method Village.add_part]. It keeps no
## pointer to its village: the village is handed to every call. A part that
## sleeps on a timer binds the village into the timer instead. Closing the
## village drops its timers, so nothing is held for ever. Override only what
## the part needs.


## Runs once, when the part is hung on [param _village].
func start(_village: Village) -> void:
	pass


## Runs once every tick, after the timers that were due. Leave it empty when
## the part only acts on timers and commands: nothing should poll.
func tick(_village: Village) -> void:
	pass


## Runs once, when the village is closed. Let go of everything here.
func close() -> void:
	pass


## The part as plain data. Two parts with the same snapshot are the same.
func snapshot() -> Dictionary:
	return {}
