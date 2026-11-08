extends CanvasLayer

@onready var _resource_labels := {
	"wood": $WoodLabel,
	"stone": $StoneLabel,
	"food": $FoodLabel,
}
@onready var _meeple_label : Label = $MeepleLabel
@onready var _job_label : Label = $JobLabel

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	JobSystem.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for kind in _resource_labels:
		_resource_labels[kind].text = "%s: %d" % [kind.capitalize(), Inventory.count(kind)]
	_meeple_label.text = "Meeples: %d / %d" % [JobSystem.workers.size(), Population.capacity()]
	_job_label.text = "Jobs: %d / %d" % [JobSystem.job_count(), JobSystem.capacity()]
