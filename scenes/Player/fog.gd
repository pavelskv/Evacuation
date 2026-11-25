extends ColorRect

@onready var camera = $"Head/Camera3D"
var tween: Tween

func _ready() -> void:
	material.set_shader_parameter("density", 0.0)

func _process(_delta: float) -> void:
	if is_node_ready() and visible and camera:
		material.set_shader_parameter("camera_position", camera.global_position)
		material.set_shader_parameter("camera_offset", camera.offset)
		position = camera.global_position - get_viewport_rect().size / 2.0
		position += camera.offset

func fade_in_fog(duration: float = 5.0, target_alpha: float = 0.7) -> void:
	if tween and tween.is_valid():
		tween.kill()
	
	tween = create_tween()
	
	tween.tween_method(
		func(value): material.set_shader_parameter("density", value),
		0.0,
		target_alpha,
		duration
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_callback(_on_fog_finished)
	
func _on_fog_finished() -> void:
	print("тюкнулся")
	pass

func fade_out_fog(duration: float = 3.0) -> void:
	if tween and tween.is_valid():
		tween.kill()
	
	tween = create_tween()
	
	tween.tween_method(
		func(value): material.set_shader_parameter("density", value),
		material.get_shader_parameter("density"),
		0.0,
		duration
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
