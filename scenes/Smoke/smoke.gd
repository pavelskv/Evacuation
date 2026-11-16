extends Node3D

## Дым идёт постоянно. Когда игрок в зоне — экран плавно темнеет.
## Когда экран полностью чёрный — игрок умирает.

## За сколько секунд в дыму экран становится полностью чёрным
@export var time_to_death: float = 4.0

@onready var area: Area3D = $Area3D
@onready var vignette_rect: ColorRect = $CanvasLayer/ColorRect

var _player: Node = null
var _time_inside: float = 0.0
var _vignette_mat: ShaderMaterial
var _dead: bool = false


func _ready() -> void:
	_vignette_mat = vignette_rect.material as ShaderMaterial
	if _vignette_mat == null:
		push_error("На ColorRect не назначен ShaderMaterial с виньеткой!")
	else:
		_vignette_mat.set_shader_parameter("intensity", 0.0)

	vignette_rect.visible = false

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _player == null or _dead:
		return

	_time_inside += delta

	# Линейно от 0 до 1 за time_to_death секунд
	var linear_t := clampf(_time_inside / time_to_death, 0.0, 1.0)
	
	var t := ease(linear_t, 0.5)

	if _vignette_mat:
		_vignette_mat.set_shader_parameter("intensity", t)

	vignette_rect.visible = t > 0.001

	# Экран полностью чёрный — смерть
	if t >= 1.0:
		_kill_player()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	_time_inside = 0.0
	_dead = false
	vignette_rect.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body != _player:
		return
	_player = null

	# Если игрок вышел до смерти — плавно гасим затемнение
	if not _dead:
		_fade_out()


func _fade_out() -> void:
	var current := 0.0
	if _vignette_mat:
		current = _vignette_mat.get_shader_parameter("intensity")

	var tween := create_tween()
	tween.tween_method(
		func(v: float):
			if _vignette_mat:
				_vignette_mat.set_shader_parameter("intensity", v),
		current,
		0.0,
		0.6
	)
	tween.tween_callback(func(): vignette_rect.visible = false)


func _kill_player() -> void:
	if _dead:
		return
	_dead = true

	EvacuationManager.fail("Длительное нахождение в зоне задымления")
