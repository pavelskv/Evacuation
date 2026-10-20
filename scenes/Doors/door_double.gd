extends Interactable

@export var open_angle: float = 90.0
@export var duration: float = 0.5
@export var invert: bool = false
@export var opened: bool = false

var is_open := false
var tween: Tween

@onready var pivot_left: Node3D = $PivotLeft
@onready var pivot_right: Node3D = $PivotRight

func get_message() -> String:
	return "Закрыть дверь [E]" if is_open else "Открыть дверь [E]"
	
func _ready() -> void:
	is_open = opened
	
	if opened:
		var dir := -1.0 if invert else 1.0
		pivot_left.rotation_degrees.y = open_angle * dir
		pivot_right.rotation_degrees.y = -open_angle * dir

func interact() -> void:
	is_open = not is_open
	if tween and tween.is_valid():
		tween.kill()

	var dir := -1.0 if invert else 1.0
	var left_target  :=  open_angle * dir if is_open else 0.0
	var right_target := -open_angle * dir if is_open else 0.0

	tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pivot_left,  "rotation_degrees:y", left_target,  duration)
	tween.tween_property(pivot_right, "rotation_degrees:y", right_target, duration)
