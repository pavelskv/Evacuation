extends Node

signal state_changed(old_state: State, new_state: State)

enum State {
	PLAYING,      # Игра
	PAUSED,       # Пауза
}

var selected_door_id: int = -1

var _state: State = State.PLAYING

func get_state() -> State:
	return _state

func is_playing() -> bool:
	return _state == State.PLAYING

func is_paused() -> bool:
	return _state == State.PAUSED
	
func set_state(new_state: State) -> void:
	if _state == new_state:
		return
	
	var old_state = _state
	_state = new_state
	state_changed.emit(old_state, new_state)
	
	Debug.d("Состояние изменено: " + State.keys()[old_state] + " → " + State.keys()[new_state])

func pause_game() -> void:
	set_state(State.PAUSED)

func resume_game() -> void:
	set_state(State.PLAYING)
