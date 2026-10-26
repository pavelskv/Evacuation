extends Interactable

enum HingeSide {
	LEFT,
	RIGHT 
}

@export var hinge_side: HingeSide = HingeSide.LEFT
@export var open_angle: float = 90.0
@export var duration: float = 0.5
@export var start_open: bool = false

@onready var pivot = $window_active

var is_open: bool = false
var tween: Tween

func _ready() -> void:
	add_to_group("training_task_objects")
	
	is_open = start_open
	pivot.rotation_degrees.y = _get_target_angle()
	
func _get_target_angle() -> float:
	if not is_open:
		return 0.0
	return open_angle if hinge_side == HingeSide.LEFT else -open_angle
	
func is_task_completed() -> bool:
	return not is_open

func interact():
	is_open = not is_open
	notify_state_changed()
	
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)	
	tween.tween_property(pivot, "rotation_degrees:y", _get_target_angle(), duration)
	
func get_message() -> String:
	return "Закрыть окно [E]" if is_open else "Открыть окно [E]"
	
func get_training_task_id() -> StringName:
	return &"close_windows"
