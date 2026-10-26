extends Node3D

@onready var pause_menu: CanvasLayer = $PauseMenu

func _ready() -> void:
	GameState.set_state(GameState.State.PLAYING)
	pause_menu.visible = false
	BrowserInputFixes.pointer_lock_lost.connect(_on_pointer_lock_lost)
	Debug.i("Уровень загружен")
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		
	if event.is_action_pressed("ui_focus_next"):
		EvacuationManager.complete_scenario()
		
	if event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
func _toggle_pause() -> void:
	if GameState.is_playing():
		pause_menu.open()
	elif GameState.is_paused():
		pause_menu.close()
		
func _on_pointer_lock_lost() -> void:
	if GameState.is_playing():
		pause_menu.open()
