class_name CrosshairController
extends CanvasLayer

@onready var crosshair_basic: TextureRect = $CenterContainer/CrosshairBasic
@onready var crosshair_hand_opened: TextureRect = $CenterContainer/CrosshairHandOpened
@onready var crosshair_hand_closed: TextureRect = $CenterContainer/CrosshairHandClosed

var is_interactable: bool = false

func _ready() -> void:
	GameState.state_changed.connect(_on_game_state_changed)
	_update_from_game_state()

func _process(_delta: float) -> void:
	if not is_interactable:
		show_basic()
		return

	if Input.is_action_pressed("mouse_left") or Input.is_action_pressed("ui_interact"):
		show_hand_closed()
	else:
		show_hand_opened()

func _on_game_state_changed(
	_old_state: GameState.State,
	new_state: GameState.State
) -> void:
	visible = new_state == GameState.State.PLAYING

func _update_from_game_state() -> void:
	visible = GameState.is_playing()

func set_interactable(value: bool) -> void:
	is_interactable = value

	if not value:
		show_basic()

func show_basic() -> void:
	crosshair_basic.visible = true
	crosshair_hand_opened.visible = false
	crosshair_hand_closed.visible = false

func show_hand_opened() -> void:
	crosshair_basic.visible = false
	crosshair_hand_opened.visible = true
	crosshair_hand_closed.visible = false

func show_hand_closed() -> void:
	crosshair_basic.visible = false
	crosshair_hand_opened.visible = false
	crosshair_hand_closed.visible = true
