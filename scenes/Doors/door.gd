extends Interactable

enum HingeSide {
	LEFT,   # Петли слева
	RIGHT   # Петли справа
}

@export var hinge_side: HingeSide = HingeSide.LEFT
@export var open_angle: float = 90.0
@export var duration: float = 0.5

@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var pitch_jitter: float = 0.05

var is_open = false
var tween: Tween
@onready var pivot = $Pivot
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer

func _ready() -> void:
	add_to_group("training_task_objects")
	
func on_focus(value: bool) -> void:
	$"Pivot/4_et_door_1/wall_door_038".material_overlay = outline if value else null

func get_message() -> String:
	return "Закрыть дверь " if is_open else "Открыть дверь "

func get_training_task_id() -> StringName:
	return &"close_door"

func is_task_completed() -> bool:
	return not is_open

func interact():
	is_open = !is_open
	notify_state_changed()
	
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
		_play_door_sound(open_sound)
	
	tween.tween_property(pivot, "rotation_degrees:y", target_angle, duration)

	if not is_open:
		tween.finished.connect(func(): _play_door_sound(close_sound), CONNECT_ONE_SHOT)

func _play_door_sound(stream: AudioStream) -> void:
	if not audio_player or not stream:
		return

	audio_player.stream = stream
	audio_player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	audio_player.play()
