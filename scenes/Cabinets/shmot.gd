extends Interactable

var taken := false
var interactable:= false

@onready var shmot = $shmot

func _ready() -> void:
	add_to_group("training_task_objects")
	add_to_group("shmot")
	
func set_interactable() -> void:
	interactable = true
	
func can_interact() -> bool:
	return interactable
	
func on_focus(value: bool) -> void:
	shmot.material_overlay = outline if value else null
	pass
	
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
