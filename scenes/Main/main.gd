extends Node3D

@onready var pause_menu: CanvasLayer = $PauseMenu

func _ready() -> void:
	GameState.set_state(GameState.State.PLAYING)
	pause_menu.visible = false
	Debug.i("Уровень загружен")
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		
func _toggle_pause() -> void:
	if GameState.is_playing():
		pause_menu.open()
	elif GameState.is_paused():
		pause_menu.close()
