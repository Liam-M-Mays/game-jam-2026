extends CanvasLayer

@onready var wood_label : Label = $WoodLabel
@onready var stone_label : Label = $StoneLabel
@onready var food_label : Label = $FoodLabel

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	wood_label.text = "Wood: %d" % Inventory.wood
	stone_label.text = "Stone: %d" % Inventory.stone
	food_label.text = "Food: %d" % Inventory.food
