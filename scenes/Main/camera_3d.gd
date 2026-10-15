
extends Node3D

@export_group("Настройки движения")
@export var move_speed: float = 15.0
@export var fast_speed: float = 40.0
@export var mouse_sensitivity: float = 0.003

@export_group("Начальное положение")
@export var start_position := Vector3(20.0, 20.0, 20.0)
@export var start_rotation := Vector3(-25.0, 45.0, 0.0)

@onready var camera: Camera3D = $Camera3D

var mouse_captured: bool = false


func _ready() -> void:
	global_position = start_position

	global_rotation = Vector3(
		deg_to_rad(start_rotation.x),
		deg_to_rad(start_rotation.y),
		deg_to_rad(start_rotation.z)
	)

	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			mouse_captured = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_captured = event.pressed

			Input.mouse_mode = (
				Input.MOUSE_MODE_CAPTURED
				if mouse_captured
				else Input.MOUSE_MODE_VISIBLE
			)

			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and mouse_captured:
		rotate_y(-event.relative.x * mouse_sensitivity)

		rotate_object_local(
			Vector3.RIGHT,
			-event.relative.y * mouse_sensitivity
		)

		rotation.x = clampf(
			rotation.x,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)

		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var direction := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		direction -= global_basis.z
	if Input.is_key_pressed(KEY_S):
		direction += global_basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= global_basis.x
	if Input.is_key_pressed(KEY_D):
		direction += global_basis.x
	if Input.is_key_pressed(KEY_E):
		direction += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		direction += Vector3.DOWN

	if direction.length_squared() == 0.0:
		return

	direction = direction.normalized()

	var speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed = fast_speed

	global_position += direction * speed * delta
