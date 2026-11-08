extends Node2D
class_name MenuMeepleSpawner

const MENU_MEEPLE := preload("res://assets/Scenes/Meeple/menu_meeple.tscn")

@export var front_layer : Node2D
@export_range(0.0, 1.0) var front_chance := 0.25
@export var min_delay := 0.005
@export var max_delay := 0.015
@export var min_fall_speed := 220.0
@export var max_fall_speed := 480.0
@export var meeple_size := 10.0
@export_range(0.0, 1.0) var tilt_chance := 0.5
@export_range(0.0, 180.0) var max_tilt_degrees := 35.0
@export_range(0.0, 1.0) var spin_chance := 0.35
@export var max_spin_degrees := 90.0

var _wait := 0.0

func _process(delta : float) -> void:
	_wait -= delta
	while _wait <= 0.0:
		_wait += randf_range(min_delay, max_delay)
		_spawn()

func _spawn() -> void:
	var meeple : MenuMeeple = MENU_MEEPLE.instantiate()
	meeple.position = Vector2(randf_range(0.0, get_viewport_rect().size.x), -MenuMeeple.OFFSCREEN)
	meeple.scale = Vector2.ONE * meeple_size
	meeple.fall_speed = randf_range(min_fall_speed, max_fall_speed)
	if randf() < tilt_chance:
		meeple.rotation = deg_to_rad(randf_range(-max_tilt_degrees, max_tilt_degrees))
	if randf() < spin_chance:
		meeple.spin = deg_to_rad(randf_range(-max_spin_degrees, max_spin_degrees))
	var layer : Node2D = front_layer if randf() < front_chance else self
	layer.add_child(meeple)
