extends GridObject
class_name Harvestable

const BREAK_EFFECT := preload("res://assets/Scenes/Resources/break.tscn")
const BREAK_HOLD := 0.06
const WOBBLE_DURATION := 0.25
const SQUASH_DURATION := 0.2

@export var wobble_interval := 0.6
@export var wobbles_to_break := 4
@export var wobble_angle := 3.0
@export var squash_amount := 0.15
@export var drops : Dictionary[PackedScene, int] = {}

@export_group("Spawning")
@export_range(0.0, 1.0, 0.001) var spawn_chance := 0.0
@export var edge_distance_curve : Curve
@export var cluster_bonus := 0.0

var _wobbles := 0
var _job : HarvestJob = null

func _on_clicked() -> void:
	if _job != null:
		JobSystem.cancel(_job)
		_set_job(null)
	elif can_harvest():
		var job := HarvestJob.new(self)
		if JobSystem.add(job):
			_set_job(job)
		else:
			reject()

func can_harvest() -> bool:
	return _wobbles < wobbles_to_break

func harvest() -> bool:
	var done := _hit()
	if done:
		_set_job(null)
	return done

func _hit() -> bool:
	_wobbles += 1
	if _wobbles < wobbles_to_break:
		_react()
		return false
	_squash()
	var tween := _start_flash(Color.WHITE)
	tween.tween_interval(BREAK_HOLD)
	tween.tween_callback(_break)
	return true

func _react() -> void:
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

func _set_job(job : HarvestJob) -> void:
	_job = job
	set_selected(job != null)

func _break() -> void:
	spawn_effect(BREAK_EFFECT)
	grid.remove(self)
	for scene in drops:
		for i in range(drops[scene]):
			var drop : ResourceDrop = scene.instantiate()
			drop.position = position + Vector2(_base_offset.x * _base_scale.x, 0)
			get_parent().add_child(drop)
			drop.launch(grid)
