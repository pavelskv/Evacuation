extends Interactable

@export var open_angle: float = 90.0
@export var duration: float = 0.5
@export var invert: bool = false
@export var opened: bool = false

@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var pitch_jitter: float = 0.05

var is_open := false
var tween: Tween

@onready var pivot_left: Node3D = $PivotLeft
@onready var pivot_right: Node3D = $PivotRight
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer

func get_message() -> String:
	return "Закрыть дверь " if is_open else "Открыть дверь "
	
func _ready() -> void:
	is_open = opened
	
	if opened:
		var dir := -1.0 if invert else 1.0
		pivot_left.rotation_degrees.y = open_angle * dir
		pivot_right.rotation_degrees.y = -open_angle * dir

func on_focus(value: bool) -> void:
	$PivotLeft/kor_L/door_11_003.material_overlay = outline if value else null
	$PivotRight/kor_R/door_11_002.material_overlay = outline if value else null

func interact() -> void:
	is_open = not is_open
	if tween and tween.is_valid():
		tween.kill()

	var dir := -1.0 if invert else 1.0
	var left_target  :=  open_angle * dir if is_open else 0.0
	var right_target := -open_angle * dir if is_open else 0.0

	var sound = open_sound if is_open else close_sound
	_play_sound(sound)

	tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pivot_left,  "rotation_degrees:y", left_target,  duration)
	tween.tween_property(pivot_right, "rotation_degrees:y", right_target, duration)
	
	#tween.finished.connect(func(): _play_sound(sound), CONNECT_ONE_SHOT)

func _play_sound(stream: AudioStream) -> void:
	if not audio_player or not stream:
		return

	audio_player.stream = stream
	audio_player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	audio_player.play()
