extends Interactable

@export var floor_number: int = 1
@export var plan_texture: Texture2D

var is_viewed: bool = false

func get_message() -> String:
	return "Посмотреть план эвакуации (%d-й этаж)  [E]" % floor_number
	
func get_training_task_id() -> StringName:
	return &"view_plan"
	
func is_task_completed() -> bool:
	return is_viewed

func _ready() -> void:
	add_to_group("training_task_objects")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func interact():
	if plan_texture == null:
		return

	var viewer := get_tree().get_first_node_in_group(
		"plan_viewer"
	)

	if viewer:
		viewer.show_painting(plan_texture)
		is_viewed = true
		notify_state_changed()
