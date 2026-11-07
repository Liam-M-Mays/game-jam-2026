extends Node2D
## Attach to any Node2D / Sprite2D. Stays on its layer, then every interval it drops
## back a layer (z_index - 1) for a short time, returns to its layer, and repeats.
 
@export var interval := 10.0       ## Seconds on the normal layer between each drop
@export var back_duration := 0.5   ## Seconds spent one layer back
@export var layers_back := 1       ## How many layers to drop
@export var start_delay := 0.0     ## Seconds to wait before the first cycle
 
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
 
