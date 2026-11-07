extends Node

signal changed

var wood := 0
var stone := 0

func add(wood_amount : int, stone_amount : int) -> void:
	wood += wood_amount
	stone += stone_amount
	changed.emit()
