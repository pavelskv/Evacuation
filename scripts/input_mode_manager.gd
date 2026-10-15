extends Node

enum InputMode {
	VISIBLE,      # Курсор виден (меню, пауза)
	HIDDEN,       # Курсор скрыт (игра, но не захвачен)
	CAPTURED,     # Курсор захвачен (игра)
}

var _current_mode: InputMode = InputMode.VISIBLE
 
func _ready() -> void:
	GameState.state_changed.connect(_on_game_state_changed)
	_set_mode(InputMode.VISIBLE, Input.MOUSE_MODE_VISIBLE)
	
func _on_game_state_changed(old_state: GameState.State, new_state: GameState.State) -> void:
	match new_state:
		GameState.State.PLAYING:
			set_captured()
		GameState.State.PAUSED:
			set_visible()
		_:
			set_visible()

func get_mode() -> InputMode:
	return _current_mode

func is_visible() -> bool:
	return _current_mode == InputMode.VISIBLE

func is_captured() -> bool:
	return _current_mode == InputMode.CAPTURED

func is_hidden() -> bool:
	return _current_mode == InputMode.HIDDEN

func set_visible() -> void:
	_set_mode(InputMode.VISIBLE, Input.MOUSE_MODE_VISIBLE)

func set_hidden() -> void:
	_set_mode(InputMode.HIDDEN, Input.MOUSE_MODE_HIDDEN)

func set_captured() -> void:
	_set_mode(InputMode.CAPTURED, Input.MOUSE_MODE_CAPTURED)

func _set_mode(mode: InputMode, godot_mode: Input.MouseMode) -> void:
	if _current_mode == mode:
		return
	
	_current_mode = mode
	Input.mouse_mode = godot_mode
	
	Debug.d("Курсор: " + InputMode.keys()[mode])
