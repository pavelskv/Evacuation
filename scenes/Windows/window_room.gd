extends Interactable

var is_open: bool = true

func _ready() -> void:
	add_to_group("training_task_objects")
	
func is_task_completed() -> bool:
	return not is_open

func interact():
	is_open = not is_open
	notify_state_changed()
	
func get_message() -> String:
	return "Закрыть окно [E]" if is_open else "Открыть окно [E]"
	
func get_training_task_id() -> StringName:
	return &"close_windows"
