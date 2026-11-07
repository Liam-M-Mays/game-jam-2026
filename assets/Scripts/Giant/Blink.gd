extends Node2D

@export var interval := 10.0
@export var back_duration := 0.5
@export var layers_back := 1
@export var start_delay := 0.0

var base_z: int

func _ready() -> void:
	base_z = z_index
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	layer_loop()

func layer_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(interval).timeout
		z_index = base_z - layers_back
		await get_tree().create_timer(back_duration).timeout
		z_index = base_z

