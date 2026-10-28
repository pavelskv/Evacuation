extends Interactable

@export var screen_on_material: Material
@export var fade_time := 0.1

var _mat: StandardMaterial3D
var _tween: Tween

@onready var screen = $monitor_2/Screen

var enabled := false

func set_interactable() -> void:
	enabled = true
	set_screen(true)

func _ready() -> void:
	add_to_group("training_task_objects")
	add_to_group("pc")
	
	_mat = screen_on_material.duplicate() as StandardMaterial3D
	screen.material_override = _mat
	set_screen(false, false)
	
func can_interact() -> bool:
	return enabled
	
func set_screen(on: bool, animated := true) -> void:
	var target := Color.WHITE if on else Color.BLACK

	if _tween:
		_tween.kill()

	if not animated:
		_mat.albedo_color = target
		return

	_tween = create_tween()
	_tween.tween_property(_mat, "albedo_color", target, fade_time)
	
func interact():
	if not can_interact():
		return
	
	enabled = not enabled
	set_screen(enabled)
	
	notify_state_changed()
	
func get_training_task_id() -> StringName:
	return &"turn_off_electrical"

func is_task_completed() -> bool:
	return not enabled

func _process(delta: float) -> void:
	pass
