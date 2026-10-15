extends CanvasLayer

signal pause_opened()
signal pause_closed()

var _is_open: bool = false

func _ready():
	pass

func _process(_delta: float) -> void:
	pass
	
func open() -> void:
	if _is_open:
		return
	
	_is_open = true
	visible = true
	#main_panel.visible = true
	#tasks_panel.visible = false
	#materials_panel.visible = false
	
	GameState.set_state(GameState.State.PAUSED)
	get_tree().paused = true
	
	pause_opened.emit()
	Debug.i("Пауза открыта")
	
func close() -> void:
	if not _is_open:
		return
	
	_is_open = false
	visible = false
	
	GameState.set_state(GameState.State.PLAYING)
	get_tree().paused = false
	
	pause_closed.emit()
	Debug.i("Пауза закрыта")

func _on_resume_button_pressed() -> void:
	close()

func _on_restart_button_pressed() -> void:
	Debug.i("Выход в главное меню")
	
	get_tree().paused = false
	GameState.set_state(GameState.State.PAUSED)
	get_tree().change_scene_to_file("res://scenes/UI/MainMenu/main_menu.tscn")

func visibility(val: bool) -> void:
	if val:
		$Control/MarginLabel.visible = true
		$Control/VBoxContainerMenu.visible = true
		$Control/MarginKeyboard.visible = true
		$Control/MarginMouse.visible = true
	else:
		$Control/MarginLabel.visible = false
		$Control/VBoxContainerMenu.visible = false
		$Control/MarginKeyboard.visible = false
		$Control/MarginMouse.visible = false

func _on_task_button_pressed():
	# Выключить меню паузы
	visibility(false)
	
	# Заменить его на меню с информацией о задачах
	$Control/Tasks_menu.visible = true


func _on_materials_button_pressed():
	# Выключить меню паузы
	visibility(false)
	
	# Заменить его на меню с информацией о задачах
	$Control/Materials_menu.visible = true
