extends CharacterBody3D

const WALK_SPEED = 3.0
const RUN_SPEED = 6.0
const ACCELERATION = 10.0
const DECELERATION = 10.0
const GRAVITY = 9.8
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

# Покачивание головы (head bob)
@export var head_bob_enabled: bool = true
@export var bob_freq: float = 5.4
@export var bob_amp: float = 0.018

# Звуки шагов
@export var footstep_sounds: Array[AudioStream] = []
@export var land_sound: AudioStream
@export var step_distance: float = 2.2
@export var pitch_jitter: float = 0.08
@export var walk_volume_db: float = -4.0
@export var run_volume_db: float = 0.0

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var raycast = $Head/Camera3D/RayCast3D
@onready var interact_container = $CrosshairController/HintContainer
@onready var interact_label = $CrosshairController/HintContainer/InteractLabel
@onready var crosshair = $CrosshairController
@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer
@onready var smoke: ColorRect = $CanvasLayer/Smoke

var current_speed = WALK_SPEED
var e_pressed = false

var _focused: Interactable = null
var _distance_accumulator: float = 0.0
var _was_on_floor: bool = true
var _t_bob: float = 0.0

func _ready():
	add_to_group("player")
	
	if interact_container:
		interact_container.visible = false

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	var e_down = Input.is_physical_key_pressed(KEY_E) or Input.is_action_pressed("mouse_left")
	if e_down and not e_pressed:
		_interact()
	e_pressed = e_down

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_physical_key_pressed(KEY_SHIFT):
		current_speed = RUN_SPEED
	else:
		current_speed = WALK_SPEED

	var input_dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1
	input_dir = input_dir.normalized()

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, ACCELERATION * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, ACCELERATION * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = lerp(velocity.z, 0.0, DECELERATION * delta)

	move_and_slide()
	_handle_headbob(delta)
	_handle_footsteps(delta)

	_check_interact()

func _handle_headbob(delta: float) -> void:
	if not camera:
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if head_bob_enabled and is_on_floor() and horizontal_speed > 0.2:
		_t_bob += delta * horizontal_speed
		var target_pos := Vector3(
			cos(_t_bob * bob_freq * 0.5) * bob_amp,
			sin(_t_bob * bob_freq) * bob_amp,
			0.0
		)
		camera.position = camera.position.lerp(target_pos, 14.0 * delta)
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, 10.0 * delta)

func _handle_footsteps(delta: float) -> void:
	var on_floor := is_on_floor()

	if on_floor and not _was_on_floor and land_sound and footstep_player:
		footstep_player.stream = land_sound
		footstep_player.pitch_scale = randf_range(0.95, 1.05)
		footstep_player.volume_db = run_volume_db
		footstep_player.play()

	_was_on_floor = on_floor

	if not on_floor or footstep_sounds.is_empty() or not footstep_player:
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.2:
		_distance_accumulator += horizontal_speed * delta
		if _distance_accumulator >= step_distance:
			_distance_accumulator -= step_distance
			_play_footstep(horizontal_speed > (WALK_SPEED + RUN_SPEED) * 0.5)
	else:
		_distance_accumulator = max(_distance_accumulator - delta * 4.0, 0.0)

func _play_footstep(is_running: bool) -> void:
	footstep_player.stream = footstep_sounds.pick_random()
	footstep_player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	footstep_player.volume_db = run_volume_db if is_running else walk_volume_db
	footstep_player.play()

func _get_interactable() -> Interactable:
	if not raycast.is_colliding():
		return null

	var collider = raycast.get_collider()
	var node = collider

	while node:
		if node is Interactable:
			if node.can_interact():
				return node
			return null

		node = node.get_parent()

	return null

func _check_interact():
	var interactable = _get_interactable()

	if interactable != _focused:
		if is_instance_valid(_focused):
			_focused.on_focus(false)
		_focused = interactable
		if _focused:
			_focused.on_focus(true)

	if not interact_label:
		return

	if interactable:
		crosshair.set_interactable(true)
		interact_label.text = interactable.get_message()
		interact_container.visible = true
	else:
		crosshair.set_interactable(false)
		interact_container.visible = false

func _interact():
	var interactable = _get_interactable()
	if interactable:
		interactable.interact()
		
func change_visibility_hints(visible: bool): 
	interact_label.visible = visible
	crosshair.visible = visible
	
func fade_in_fog(duration: float = 5.0, target_alpha: float = 0.7) -> void:
	smoke.fade_in_fog(duration, target_alpha)
