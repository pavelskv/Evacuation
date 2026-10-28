extends Interactable

enum HingeSide {
	LEFT,
	RIGHT
}

@export var hinge_side: HingeSide = HingeSide.LEFT
@export var open_angle: float = 90.0
@export var duration: float = 0.5
@export var start_open: bool = false

@onready var pivot: Node3D = $window_active

var is_open: bool = false
var tween: Tween


func _ready() -> void:
	add_to_group("training_task_objects")
	add_to_group("windows")

	is_open = start_open
	pivot.rotation_degrees.y = _get_target_angle()
	
func can_interact() -> bool:
	return is_open

func set_initial_state(opened: bool) -> void:
	is_open = opened

	if is_node_ready():
		pivot.rotation_degrees.y = _get_target_angle()

func _get_target_angle() -> float:
	if not is_open:
		return 0.0

	return open_angle if hinge_side == HingeSide.LEFT else -open_angle


func interact() -> void:
	if not can_interact():
		return
	
	is_open = not is_open
	notify_state_changed()

	if tween and tween.is_valid():
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		pivot,
		"rotation_degrees:y",
		_get_target_angle(),
		duration
	)


func get_message() -> String:
	return "Закрыть окно " if is_open else ""


func get_training_task_id() -> StringName:
	return &"close_windows"


func is_task_completed() -> bool:
	return not is_open
