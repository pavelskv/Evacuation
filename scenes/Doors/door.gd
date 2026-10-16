extends Interactable

enum HingeSide {
	LEFT,   # Петли слева
	RIGHT   # Петли справа
}

@export var hinge_side: HingeSide = HingeSide.LEFT
@export var open_angle: float = 90.0
@export var duration: float = 0.5

var is_open = false
var tween: Tween
@onready var pivot = $Pivot

func get_message() -> String:
	return "Закрыть дверь [E]" if is_open else "Открыть дверь [E]"

func interact():
	is_open = !is_open
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	
	var target_angle = 0.0
	if is_open:
		if hinge_side == HingeSide.LEFT:
			target_angle = open_angle
		else:
			target_angle = -open_angle
	
	tween.tween_property(pivot, "rotation_degrees:y", target_angle, duration)
