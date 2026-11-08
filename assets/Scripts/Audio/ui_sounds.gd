extends Node

const CLICK := preload("res://assets/Audio/UI/click.wav")
const WARNING := preload("res://assets/Audio/UI/warning.wav")
const CLICK_DB := -14.0
const WARNING_DB := -14.0
const NORMAL_SPEED_INDEX := 0

var _click := AudioStreamPlayer.new()
var _warning := AudioStreamPlayer.new()

func _ready() -> void:
	_click.stream = CLICK
	_click.volume_db = CLICK_DB
	add_child(_click)
	_warning.stream = WARNING
	_warning.volume_db = WARNING_DB
	add_child(_warning)
	GameState.toast_requested.connect(_on_toast_requested)
	get_tree().node_added.connect(_on_node_added)
	_connect_existing(get_tree().root)

func _connect_existing(node : Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_connect_existing(child)

func _on_node_added(node : Node) -> void:
	var button := node as BaseButton
	if button != null and not button.pressed.is_connected(_play_click):
		button.pressed.connect(_play_click)

func _play_click() -> void:
	_click.play()

func _on_toast_requested(_text : String, kind : int) -> void:
	if kind != GameState.ToastKind.WARNING:
		return
	_warning.play()
	if GameState.speed > GameState.SPEEDS[NORMAL_SPEED_INDEX]:
		GameState.set_speed_index(NORMAL_SPEED_INDEX)
