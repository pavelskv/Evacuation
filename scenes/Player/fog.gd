extends ColorRect

@onready var camera = $"../../Head/Camera3D"
var tween: Tween

var _density := 0.0
var _gradient: Gradient
var _orig_alphas: Array[float] = []

func _ready() -> void:
	material = material.duplicate()
	var tex := (material.get_shader_parameter("color_gradient") as GradientTexture1D).duplicate() as GradientTexture1D
	tex.gradient = tex.gradient.duplicate()
	material.set_shader_parameter("color_gradient", tex)

	_gradient = tex.gradient
	for i in _gradient.get_point_count():
		_orig_alphas.append(_gradient.get_color(i).a)

	_set_density(0.0)

func _set_density(value: float) -> void:
	_density = value
	for i in _gradient.get_point_count():
		var c := _gradient.get_color(i)
		c.a = _orig_alphas[i] * value
		_gradient.set_color(i, c)

func fade_in_fog(duration: float = 5.0, target_alpha: float = 0.7) -> void:
	if tween and tween.is_valid():
		tween.kill()

	tween = create_tween()
	tween.tween_method(_set_density, _density, target_alpha, duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_on_fog_finished)

func _on_fog_finished() -> void:
	EvacuationManager.fail("Длительное нахождение в зоне задымления")

func fade_out_fog(duration: float = 3.0) -> void:
	if tween and tween.is_valid():
		tween.kill()

	tween = create_tween()
	tween.tween_method(_set_density, _density, 0.0, duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
