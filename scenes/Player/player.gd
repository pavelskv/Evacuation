extends CharacterBody3D

const WALK_SPEED = 3.0
const RUN_SPEED = 6.0
const ACCELERATION = 10.0
const DECELERATION = 10.0
const GRAVITY = 9.8
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var raycast = $Head/Camera3D/RayCast3D
@onready var interact_container = $CrosshairController/HintContainer
@onready var interact_label = $CrosshairController/HintContainer/InteractLabel
@onready var crosshair = $CrosshairController

var current_speed = WALK_SPEED
var e_pressed = false

var _focused: Interactable = null

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

	_check_interact()

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
