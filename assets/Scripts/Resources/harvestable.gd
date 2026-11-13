extends GridObject
class_name Harvestable

const BREAK_EFFECT := preload("res://assets/Scenes/Effects/break.tscn")
const BREAK_HOLD := 0.06
const WOBBLE_DURATION := 0.25
const SQUASH_DURATION := 0.2
const GROW_DURATION := 0.5

@export var wobble_interval := 0.6
@export var wobbles_to_break := 4
@export var wobble_angle := 3.0
@export var squash_amount := 0.15
@export var drops : Dictionary[PackedScene, int] = {}
@export var food_cost := 0
@export var hit_sound := &""

@export_group("Spawning")
@export var target_count := 0
@export_range(0.0, 1.0, 0.01) var respawn_chance := 0.5
@export var edge_distance_curve : Curve
@export var cluster_bonus := 0.0

## Its data on the grid. The wobble count lives there, so it stays while the tree is drawn by its row.
var standing : Standing
var _job : Job = null

func _ready() -> void:
	super()
	# The grid finds trees and rocks under the mouse through its cells, and hovers and clicks them.
	area.input_pickable = false

## True when nothing is happening to it, so the grid can draw it with its row again.
func is_still() -> bool:
	return _job == null and _tweens.values().all(func(tween : Tween) -> bool: return not tween.is_running())

## The picture its row draws for `item` while it has no node.
func texture_for(_item : Standing) -> Texture2D:
	return texture

func grow_in() -> void:
	scale = _base_scale * Vector2(0.4, 0.05)
	var tween := _tween(&"squash").set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _base_scale, GROW_DURATION)

func _on_clicked() -> void:
	if _job is HarvestJob:
		JobSystem.cancel(_job)
		_set_job(null)
	elif _job != null:
		reject()
		GameState.warn("A lumberjack or miner is already working on this")
	elif can_harvest():
		var job := HarvestJob.new(self)
		JobSystem.add(job)
		_set_job(job)

## Cancels the job the player gave it and takes the mark off.
func cancel_job() -> void:
	JobSystem.cancel(_job)
	_set_job(null)

func can_harvest() -> bool:
	return standing.wobbles < wobbles_to_break

func is_free() -> bool:
	return _job == null and can_harvest()

func claim(job : Job) -> void:
	_job = job

func release(job : Job) -> void:
	if _job == job:
		_job = null

func harvest() -> bool:
	var done := _hit()
	if done:
		_set_job(null)
	return done

func _hit() -> bool:
	standing.wobbles += 1
	if standing.wobbles < wobbles_to_break:
		_react()
		return false
	_shatter()
	return true

func _shatter() -> void:
	standing.wobbles = wobbles_to_break
	VillageAudio.play(hit_sound, global_position)
	_squash()
	var tween := _start_flash(Color.WHITE)
	tween.tween_interval(BREAK_HOLD)
	tween.tween_callback(_break)

func _react() -> void:
	VillageAudio.play(hit_sound, global_position)
	_squash()
	flash()
	var tween := _tween(&"wobble")
	var step := WOBBLE_DURATION / 4
	tween.tween_property(self, "rotation_degrees", wobble_angle, step)
	tween.tween_property(self, "rotation_degrees", -wobble_angle, step * 2)
	tween.tween_property(self, "rotation_degrees", 0.0, step)

func _squash() -> void:
	scale = _base_scale * Vector2(1.0 + squash_amount, 1.0 - squash_amount)
	var tween := _tween(&"squash").set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _base_scale, SQUASH_DURATION)

func _set_job(job : Job) -> void:
	_job = job
	set_selected(job != null)

func _break() -> void:
	spawn_effect(BREAK_EFFECT)
	grid.remove(self)
	for scene in drops:
		for i in range(drops[scene]):
			grid.add_drop(scene, position + Vector2(_base_offset.x * _base_scale.x, 0)).launch()
