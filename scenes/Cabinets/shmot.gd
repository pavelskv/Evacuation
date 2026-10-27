extends Interactable

var taken := false

func _ready() -> void:
	add_to_group("training_task_objects")
	
func interact():
	if taken:
		return
	taken = true
	
	notify_state_changed()
	
	$shmot/StaticBody3D/CollisionShape3D.set_deferred("disabled", true)

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
	
func get_training_task_id() -> StringName:
	return &"pickup_stuff"

func is_task_completed() -> bool:
	return taken

func _process(delta: float) -> void:
	pass
