extends Interactable

var enabled := false

func set_interactable() -> void:
	enabled = true

func _ready() -> void:
	add_to_group("training_task_objects")
	add_to_group("pc")
	
func can_interact() -> bool:
	return enabled
	
func interact():
	if not can_interact():
		return
	
	enabled = not enabled
	notify_state_changed()
	
func get_training_task_id() -> StringName:
	return &"turn_off_electrical"

func is_task_completed() -> bool:
	return not enabled

func _process(delta: float) -> void:
	pass
